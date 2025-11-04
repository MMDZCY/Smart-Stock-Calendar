import akshare as ak



industry_df = ak.stock_board_industry_summary_ths()  # 返回包含行业名称的DataFrame
industry_list = industry_df["板块"].tolist()  # 提取"板块名称"列转为列表

all_industry=ak.stock_board_industry_name_ths()
print(all_industry)

industry_changes={}
industry="元件"




stock_board_industry_index_ths_df_today = ak.stock_board_industry_index_ths(symbol=industry, start_date="20251103", end_date="20251103")["收盘价"]
stock_board_industry_index_ths_df_yesterday = ak.stock_board_industry_index_ths(symbol=industry, start_date="20251031", end_date="20251031")["收盘价"]
changes=((stock_board_industry_index_ths_df_today-stock_board_industry_index_ths_df_yesterday)/stock_board_industry_index_ths_df_yesterday).iloc[0]
print(changes*100)