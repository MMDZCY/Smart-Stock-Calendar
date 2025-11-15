import akshare as ak
import pandas as pd
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from datetime import datetime, timedelta
import logging

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
    获取行业板块数据
    日期格式：YYYYMMDD，如果不提供则获取最新数据
    """
    try:

        date_str = date
        logger.info(f"获取行业板块数据：{date_str}")
        sectors = []
        
        if date_str==datetime.now().strftime("%Y%m%d"):
            
            industry_data = ak.stock_board_industry_summary_ths()
            logger.info(f"获取到{len(industry_data)}个行业板块")
        
      
            for i, row in industry_data.iterrows():
                sector_name = str(row.get("板块", ""))
                change_percent = float(row.get("涨跌幅", 0.0))
            
                if sector_name:
                    sectors.append({
                        "name": sector_name,
                        "change_percent": change_percent,
                        "date": date_str
                    })
        
        # 按涨跌幅排序
            sectors.sort(key=lambda x: x["change_percent"], reverse=True)
        
            logger.info(f"成功获取行业板块数据，共{len(sectors)}条")
            return {"code": 200, "message": "success", "data": sectors}


        else:
            industry_df = ak.stock_board_industry_summary_ths()
            industry_list = industry_df["板块"].tolist()
            today_str = date_str

            back_day=1
            while ak.stock_board_industry_index_ths(
                symbol="银行", 
                start_date=today_str, 
                end_date=today_str
                ).empty:
                    back_day+=1
                    current_date = current_date - timedelta(days=back_day)
                    today_str = current_date.strftime("%Y%m%d")
            
            current_date = datetime.strptime(date_str, "%Y%m%d")   
            yesterday_date = current_date - timedelta(days=1)
            yesterday_str = yesterday_date.strftime("%Y%m%d")  # 前一天（无横线）
            
            back_day=1
            while ak.stock_board_industry_index_ths(
                symbol="银行", 
                start_date=yesterday_str, 
                end_date=yesterday_str
                ).empty:
                    back_day+=1
                    yesterday_date = yesterday_date - timedelta(days=back_day)
                    yesterday_str = yesterday_date.strftime("%Y%m%d")  # 前一天（无横线）
                

 
            for industry in industry_list:
                # 当天数据（用当天无横线格式）
                today_df = ak.stock_board_industry_index_ths(
                    symbol=industry, 
                    start_date=today_str, 
                    end_date=today_str
                )
                # 前一天数据（用计算出的前一天无横线格式）
                yesterday_df = ak.stock_board_industry_index_ths(
                    symbol=industry, 
                    start_date=yesterday_str, 
                    end_date=yesterday_str
                )

                
                # 避免索引错误（确保数据存在）
                if not today_df.empty and not yesterday_df.empty:
                    today_close = today_df["收盘价"].iloc[0]
                    yesterday_close = yesterday_df["收盘价"].iloc[0]
                    # 计算涨跌幅
                    change = ((today_close - yesterday_close) / yesterday_close) * 100
                    sectors.append({
                        "name": industry,
                        "change_percent": round(change, 2),
                        "date": today_str
                    })
            sectors.sort(key=lambda x: x["change_percent"], reverse=True)
            return {"code": 200, "message": "success", "data": sectors}
            
            
           

    except Exception as e:
        logger.error(f"获取行业板块数据异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取行业板块数据失败: {str(e)}")





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