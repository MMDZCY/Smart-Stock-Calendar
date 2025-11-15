import akshare as ak
from datetime import datetime

df = ak.stock_sector_spot(indicator="新浪行业")
top5 = df.sort_values('涨跌幅', ascending=False).head(5)
print(top5)
print(df.columns.tolist())