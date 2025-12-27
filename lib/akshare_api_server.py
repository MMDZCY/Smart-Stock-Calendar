import akshare as ak
import pandas as pd
import sqlite3
import os
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from datetime import datetime, timedelta
import logging
from typing import Optional, Dict, List
import threading
lock = threading.Lock()
# 数据库配置
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stock_data.db")
DATA_RETENTION_DAYS = 180  # 数据保留180天（约半年）

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AkShare API服务",
    description="为Flutter应用提供股票数据API",
    version="1.0.0"
)

# 配置CORS中间件，允许Flutter应用访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应该设置具体的域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 全局异常处理
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"全局异常处理: {exc}")
    return {"code": 500, "message": f"服务器错误: {str(exc)}", "data": []}

# 请求日志中间件
@app.middleware("http")
async def log_requests(request, call_next):
    start_time = datetime.now()
    response = await call_next(request)
    process_time = (datetime.now() - start_time).total_seconds()
    logger.info(f"{request.method} {request.url.path} - 处理时间: {process_time:.3f}s")
    return response

# 数据库初始化
def init_database():
    """初始化数据库表"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        
        # 指数数据表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS index_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                date TEXT NOT NULL,
                open REAL,
                close REAL,
                high REAL,
                low REAL,
                volume REAL,
                change_percent REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(code, date)
            )
        ''')
        
        # 行业数据表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS industry_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                date TEXT NOT NULL,
                change_percent REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(name, date)
            )
        ''')
        
        # 清理过期数据（保留半年）
        cutoff_date = (datetime.now() - timedelta(days=DATA_RETENTION_DAYS)).strftime('%Y-%m-%d')
        cursor.execute("DELETE FROM index_data WHERE date < ?", (cutoff_date,))
        cursor.execute("DELETE FROM industry_data WHERE date < ?", (cutoff_date,))
        
        conn.commit()
        logger.info("数据库初始化完成")

def get_cached_index_data(code: str, target_date: str) -> Optional[Dict]:
    """从缓存获取指数数据"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT code, name, date, open, close, high, low, volume, change_percent
            FROM index_data 
            WHERE code = ? AND date = ?
        ''', (code, target_date))
        row = cursor.fetchone()
        
        if row:
            return {
                "code": row[0],
                "name": row[1],
                "date": row[2],
                "open": row[3],
                "close": row[4],
                "high": row[5],
                "low": row[6],
                "volume": row[7],
                "change_percent": row[8]
            }
    return None

def save_index_data(data: Dict):
    """保存指数数据到数据库"""
    with lock:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT OR REPLACE INTO index_data 
                (code, name, date, open, close, high, low, volume, change_percent)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                data['code'], data['name'], data['date'],
                data['open'], data['close'], data['high'], 
                data['low'], data['volume'], data['change_percent']
            ))
            conn.commit()

def get_cached_industry_data(target_date: str) -> List[Dict]:
    """从缓存获取行业数据"""
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT name, change_percent, date
            FROM industry_data 
            WHERE date = ?
            ORDER BY change_percent DESC
        ''', (target_date,))
        
        return [{
            "name": row[0],
            "change_percent": row[1],
            "date": row[2]
        } for row in cursor.fetchall()]

def save_industry_data(data_list: List[Dict]):
    """保存行业数据到数据库"""
    with lock:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            for data in data_list:
                cursor.execute('''
                    INSERT OR REPLACE INTO industry_data 
                    (name, date, change_percent)
                    VALUES (?, ?, ?)
                ''', (data['name'], data['date'], data['change_percent']))
            conn.commit()

def preload_historical_data():
    """预加载过去半年的历史数据（后台任务）"""
    logger.info("开始预加载历史数据...")
    
    try:
        # 计算过去半年的日期范围
        end_date = datetime.now()
        start_date = end_date - timedelta(days=DATA_RETENTION_DAYS)
        
        # 预加载指数数据
        for code, name in MAJOR_INDEXES.items():
            try:
                logger.info(f"正在预加载指数数据: {name}")
                index_df = ak.stock_zh_index_daily(symbol=code)
                index_df["date"] = pd.to_datetime(index_df["date"])
                
                # 筛选半年的数据
                mask = (index_df["date"] >= start_date.strftime('%Y-%m-%d')) & \
                       (index_df["date"] <= end_date.strftime('%Y-%m-%d'))
                recent_data = index_df[mask]
                
                for _, row in recent_data.iterrows():
                    date_str = row["date"].strftime('%Y-%m-%d')
                    
                    # 计算涨跌幅
                    current_idx = row.name
                    if current_idx > 0:
                        prev_close = float(index_df.iloc[current_idx - 1]["close"])
                        change_percent = round((row["close"] - prev_close) / prev_close * 100, 2)
                    else:
                        change_percent = round((row["close"] - row["open"]) / row["open"] * 100, 2)
                    
                    data = {
                        "code": code,
                        "name": name,
                        "date": date_str,
                        "open": float(row["open"]),
                        "close": float(row["close"]),
                        "high": float(row["high"]),
                        "low": float(row["low"]),
                        "volume": float(row["volume"]),
                        "change_percent": change_percent
                    }
                    save_index_data(data)
                
                logger.info(f"指数 {name} 数据预加载完成，共 {len(recent_data)} 条")
                
            except Exception as e:
                logger.error(f"预加载指数 {name} 数据失败: {e}")
                continue
        
        # 预加载行业数据（只预加载最近30天，因为历史行业数据获取较慢）
                # 预加载行业数据（最近30个交易日）
        try:
            # 先获取当前所有行业名称
            industry_summary = ak.stock_board_industry_summary_ths()
            if industry_summary.empty:
                logger.warning("无法获取行业板块列表，跳过行业数据预加载")
            else:
                industry_list = industry_summary["板块"].tolist()
                logger.info(f"获取到 {len(industry_list)} 个行业板块，开始预加载最近30个交易日数据")

                loaded_dates = set()
                for i in range(30):  # 尝试最近30天
                    candidate_date = datetime.now() - timedelta(days=i)
                    date_str_no_dash = candidate_date.strftime("%Y%m%d")
                    date_str_dash = candidate_date.strftime("%Y-%m-%d")

                    # 检查该日期是否有交易数据（用“银行”板块作为探测）
                    probe_df = ak.stock_board_industry_index_ths(symbol="银行", start_date=date_str_no_dash, end_date=date_str_no_dash)
                    if probe_df.empty:
                        continue  # 非交易日，跳过

                    # 找到前一个交易日（作为计算涨跌幅的基准）
                    prev_date = candidate_date
                    prev_date_str_no_dash = date_str_no_dash
                    for j in range(1, 10):  # 最多往前找9天
                        prev_date = candidate_date - timedelta(days=j)
                        prev_date_str_no_dash = prev_date.strftime("%Y%m%d")
                        prev_probe = ak.stock_board_industry_index_ths(symbol="银行", start_date=prev_date_str_no_dash, end_date=prev_date_str_no_dash)
                        if not prev_probe.empty:
                            break
                    else:
                        logger.warning(f"找不到 {date_str_dash} 的前一交易日，跳过该日行业数据")
                        continue

                    # 收集该交易日所有行业涨跌幅
                    daily_sectors = []
                    for industry in industry_list:
                        try:
                            today_df = ak.stock_board_industry_index_ths(symbol=industry, start_date=date_str_no_dash, end_date=date_str_no_dash)
                            yesterday_df = ak.stock_board_industry_index_ths(symbol=industry, start_date=prev_date_str_no_dash, end_date=prev_date_str_no_dash)

                            if not today_df.empty and not yesterday_df.empty:
                                today_close = float(today_df["收盘价"].iloc[0])
                                yesterday_close = float(yesterday_df["收盘价"].iloc[0])
                                change_percent = round((today_close - yesterday_close) / yesterday_close * 100, 2)
                                daily_sectors.append({
                                    "name": industry,
                                    "change_percent": change_percent,
                                    "date": date_str_dash
                                })
                        except Exception as e:
                            logger.debug(f"预加载行业 {industry} {date_str_dash} 数据失败: {e}")
                            continue

                    if daily_sectors:
                        save_industry_data(daily_sectors)
                        loaded_dates.add(date_str_dash)
                        logger.info(f"预加载行业数据完成: {date_str_dash}，共 {len(daily_sectors)} 个板块")

                logger.info(f"行业历史数据预加载完成，共加载 {len(loaded_dates)} 个交易日")
        except Exception as e:
            logger.error(f"预加载行业数据整体失败: {e}")
        
        logger.info("历史数据预加载完成")
        
    except Exception as e:
        logger.error(f"预加载历史数据失败: {e}")

# 在应用启动时初始化数据库和预加载数据
@app.on_event("startup")
async def startup_event():
    """应用启动时的初始化"""
    logger.info("正在启动AkShare API服务...")
    init_database()
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM index_data")
        index_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM industry_data")
        industry_count = cursor.fetchone()[0]
    # 在后台线程预加载历史数据
    total_records = index_count + industry_count
    if total_records < 100:  # 可以根据实际情况调整阈值，比如 < 500
        logger.info(f"数据库记录较少（{total_records}条），开始完整预加载历史数据...")
        threading.Thread(target=preload_historical_data, daemon=True).start()
    else:
        logger.info(f"数据库已有 {total_records} 条记录，跳过完整预加载（仅依赖缓存+按需拉取）")


# 健康检查端点
@app.get("/health")
async def health_check():
    return {"status": "healthy", "message": "AkShare服务运行正常"}

# 定义主要指数：代码 -> 名称（可扩展）
MAJOR_INDEXES = {
    "sh000001": "上证指数",
    "sz399001": "深证成指",
    "sz399006": "创业板指",
    "sh000300": "沪深300"  # 可根据需要添加
}


@app.get("/api/index")
async def get_index_data(
    date: str = Query(None, description="日期格式：YYYYMMDD，不提供则获取最新交易日数据")
):
    """获取主要指数数据（包含开盘、收盘、涨跌幅等）"""
    try:
        # 处理目标日期
        if date is None:
            target_date = datetime.now()  # 默认为今天
        else:
            try:
                target_date = datetime.strptime(date, "%Y%m%d")
            except ValueError:
                raise HTTPException(status_code=400, detail="日期格式错误，请使用YYYYMMDD（如20231009）")
        
        target_date_str = target_date.strftime("%Y-%m-%d")
        logger.info(f"开始获取指数数据（目标日期：{target_date_str}）")
        
        result = []
        
        for code, name in MAJOR_INDEXES.items():
            try:
                # 获取指数日线数据（接口返回DataFrame，包含date、open、close等列）
                index_df = ak.stock_zh_index_daily(symbol=code)
                # 确保日期列格式正确（转换为datetime，避免字符串格式不一致）
                index_df["date"] = pd.to_datetime(index_df["date"])
                # 提取日期字符串列（用于匹配）
                index_df["date_str"] = index_df["date"].dt.strftime("%Y-%m-%d")
                
                # 筛选目标日期的数据
                mask = index_df["date_str"] == target_date_str
                target_rows = index_df[mask]
                
                # 若目标日期无数据，尝试往前推（最多推9天，应对周末/节假日）
                days_back = 1
                while target_rows.empty and days_back <= 9:
                    prev_date = target_date - timedelta(days=days_back)
                    prev_date_str = prev_date.strftime("%Y-%m-%d")
                    logger.warning(f"指数[{name}]在{target_date_str}无数据，尝试前{days_back}天：{prev_date_str}")
                    mask_prev = index_df["date_str"] == prev_date_str
                    target_rows = index_df[mask_prev]
                    days_back += 1
                
                # 取匹配到的第一条数据（通常只有一条）
                index_data = target_rows.iloc[0]
                actual_date_str = index_data["date_str"]  # 实际获取到的日期（可能不是目标日期）
                
                # 提取基础数据（带容错的类型转换）
                try:
                    open_val = float(index_data.get("open", 0))
                    close_val = float(index_data.get("close", 0))
                    high_val = float(index_data.get("high", 0))
                    low_val = float(index_data.get("low", 0))
                    volume_val = float(index_data.get("volume", 0))  # 成交量
                except ValueError as e:
                    logger.warning(f"指数[{name}]数据格式错误：{str(e)}，跳过")
                    continue
                
                # 计算涨跌幅（基于前一日收盘价）
                # 找到前一日的数据（索引位置-1）
                current_idx = target_rows.index[0]
                if current_idx > 0:  # 确保不是第一条数据（有前一日数据）
                    prev_close = float(index_df.iloc[current_idx - 1].get("close", close_val))
                    change_percent = round((close_val - prev_close) / prev_close * 100, 2)
                else:
                    # 若没有前一日数据（如指数刚发布），用当日涨跌幅（open->close）
                    change_percent = round((close_val - open_val) / open_val * 100 if open_val != 0 else 0, 2)
                    logger.warning(f"指数[{name}]无历史数据，涨跌幅基于当日开盘价计算")
                
                result.append({
                    "name": name,
                    "code": code,
                    "open": open_val,
                    "close": close_val,
                    "high": high_val,
                    "low": low_val,
                    "volume": volume_val,
                    "change_percent": change_percent,
                    "date": actual_date_str  # 实际数据日期（可能与目标日期不同）
                })
                
            except Exception as e:
                logger.error(f"获取指数[{name}]数据失败：{str(e)}")
                continue  # 单个指数失败不影响其他指数
        
        if not result:
            raise HTTPException(status_code=500, detail="所有指数数据获取失败（可能为非交易日或接口异常）")
        
        logger.info(f"成功获取{len(result)}个指数数据")
        return {
            "code": 200,
            "message": "success",
            "data": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取指数数据异常：{str(e)}")
        raise HTTPException(status_code=500, detail=f"服务器错误：{str(e)}")

# 获取行业板块数据
@app.get("/api/industry")
async def get_industry_data(date: str = None):
    """
    获取行业板块数据（修复版：历史数据正确回溯 + 自动缓存）
    日期格式：YYYYMMDD，不提供则获取最新数据
    """
    try:
        # 处理目标日期
        if date is None:
            target_date = datetime.now()
            target_date_str = target_date.strftime('%Y-%m-%d')
            today_str = datetime.now().strftime("%Y%m%d")
            is_today = True
        else:
            target_date = datetime.strptime(date, "%Y%m%d")
            target_date_str = target_date.strftime('%Y-%m-%d')
            today_str = date
            is_today = (today_str == datetime.now().strftime("%Y%m%d"))

        # 未来日期提示
        if target_date > datetime.now():
            logger.warning(f"拒绝未来日期请求: {target_date_str}")
            return {
                "code": 400,
                "message": f"不能查询未来日期 {target_date_str}，请查询历史交易日",
                "data": [],
                "suggest": "不传date参数获取最新交易日数据"
            }

        logger.info(f"获取行业数据：请求日期={target_date_str}, 是否当天={is_today}")

        # 1. 首先检查缓存（用请求的target_date_str）
        cached_data = get_cached_industry_data(target_date_str)
        if cached_data:
            logger.info(f"✅ 缓存命中：{target_date_str}，共{len(cached_data)}条")
            return {
                "code": 200,
                "message": "success",
                "data": cached_data,
                "data_source": "cache"
            }

        # 2. 缓存未命中，实时获取
        logger.info(f"❌ 缓存未命中，实时获取 {target_date_str}")
        sectors = []

        try:
            # 获取当前所有行业列表
            summary_df = ak.stock_board_industry_summary_ths()
            if summary_df.empty:
                raise ValueError("无法获取行业板块列表")
            industry_list = summary_df["板块"].tolist()
            logger.info(f"获取到 {len(industry_list)} 个行业板块")

            # 3. 找到实际交易日（从目标日期开始往前找最多10天）
            query_date = target_date
            date_no_dash = today_str  # YYYYMMDD格式给AKShare
            actual_date_no_dash = None
            actual_date_str = None

            for back_days in range(10):  # 最多找10天前的交易日
                probe_df = ak.stock_board_industry_index_ths(
                    symbol="银行", start_date=date_no_dash, end_date=date_no_dash
                )
                if not probe_df.empty:
                    actual_date_no_dash = date_no_dash
                    actual_date_str = query_date.strftime("%Y-%m-%d")  # 用找到的日期作为缓存key
                    logger.info(f"找到实际交易日：{actual_date_str} (回溯{back_days}天)")
                    break
                
                # 往前推1天
                query_date -= timedelta(days=1)
                date_no_dash = query_date.strftime("%Y%m%d")
            else:
                raise HTTPException(status_code=404, detail=f"目标日期{target_date_str}附近10天无交易数据")

            # 4. 找到前一交易日（计算涨跌幅基准）
            prev_date = query_date - timedelta(days=1)
            prev_date_no_dash = prev_date.strftime("%Y%m%d")
            for back_days in range(1, 10):
                prev_probe = ak.stock_board_industry_index_ths(
                    symbol="银行", start_date=prev_date_no_dash, end_date=prev_date_no_dash
                )
                if not prev_probe.empty:
                    logger.info(f"找到前一交易日：{prev_date.strftime('%Y-%m-%d')}")
                    break
                prev_date -= timedelta(days=1)
                prev_date_no_dash = prev_date.strftime("%Y%m%d")
            else:
                logger.warning(f"找不到 {actual_date_str} 的前一交易日，使用开盘价基准")

            # 5. 计算所有行业涨跌幅
            success_count = 0
            for industry in industry_list:
                try:
                    today_df = ak.stock_board_industry_index_ths(
                        symbol=industry, start_date=actual_date_no_dash, end_date=actual_date_no_dash
                    )
                    yesterday_df = ak.stock_board_industry_index_ths(
                        symbol=industry, start_date=prev_date_no_dash, end_date=prev_date_no_dash
                    )

                    if not today_df.empty and not yesterday_df.empty:
                        today_close = float(today_df["收盘价"].iloc[0])
                        yesterday_close = float(yesterday_df["收盘价"].iloc[0])
                        change_percent = round((today_close - yesterday_close) / yesterday_close * 100, 2)
                        
                        sectors.append({
                            "name": str(industry),
                            "change_percent": change_percent,
                            "date": actual_date_str  # ✅ 关键：用实际交易日作为缓存日期
                        })
                        success_count += 1
                    # 即使单个行业失败，也继续其他行业
                except Exception as e:
                    logger.debug(f"行业 {industry} 数据失败: {e}")
                    continue

            # 6. ✅ 按涨跌幅排序 + 保存到数据库（用实际日期作为key）
            sectors.sort(key=lambda x: x["change_percent"], reverse=True)
            if sectors:
                # 保存时用实际交易日作为缓存key，确保下次能命中
                for sector in sectors:
                    sector["date"] = actual_date_str  # 确保一致
                save_industry_data(sectors)
                logger.info(f"✅ 保存到数据库成功！日期={actual_date_str}, 成功{len(sectors)}/{len(industry_list)}个行业")

            # 7. 返回（即使部分失败也返回可用数据）
            result = {
                "code": 200,
                "message": "success",
                "data": sectors,
                "data_source": "live"
            }
            if actual_date_str != target_date_str:
                result["note"] = f"请求日期{target_date_str}无数据，返回最近交易日{actual_date_str}"
            logger.info(f"行业数据返回：{len(sectors)}条 (实际日期: {actual_date_str})")
            return result

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"行业数据获取异常: {e}")
            raise HTTPException(status_code=500, detail=f"获取行业数据失败: {str(e)}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"行业接口全局异常: {e}")
        raise HTTPException(status_code=500, detail=f"服务器错误: {str(e)}")




if __name__ == "__main__":
    # 启动服务，监听在0.0.0.0:8000
    logger.info("AkShare API服务启动中...")
    logger.info("健康检查地址: http://localhost:8000/health")
    logger.info("指数数据地址: http://localhost:8000/api/index")
    logger.info("行业数据地址: http://localhost:8000/api/industry")


    
    try:
        uvicorn.run(
            app, 
            host="0.0.0.0", 
            port=8000,
            log_level="info",
            access_log=True,
            timeout_keep_alive=30
        )
    except KeyboardInterrupt:
        logger.info("服务被用户中断")
    except Exception as e:
        logger.error(f"服务启动失败: {e}")
        raise