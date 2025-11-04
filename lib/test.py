import akshare as ak
from datetime import datetime
b=str(20251015)
a=datetime.strptime(b, "%Y%m%d")
print(type(a))