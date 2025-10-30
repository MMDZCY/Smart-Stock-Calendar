// 农历工具类 - 实现公历和农历的相互转换

class LunarUtils {
  // 农历数据 - 1900-2100年的数据
  // ignore: constant_identifier_names
  static const List<int> LUNAR_DATA = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x16a95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04bd7, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0baa6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520
  ];

  // 农历月份名称
  static const List<String> LUNAR_MONTHS = [
    '', '正月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '冬月', '腊月'
  ];

  // 农历日期名称
  static const List<String> LUNAR_DAYS = [
    '', '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'
  ];

  // 天干
  static const List<String> HEAVENLY_STEMS = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  
  // 地支
  static const List<String> EARTHLY_BRANCHES = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
  
  // 生肖
  static const List<String> ZODIAC = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];

  // 公历转农历
  static LunarDate solarToLunar(DateTime solarDate) {
    int year = solarDate.year;
    int month = solarDate.month;
    int day = solarDate.day;

    // 计算从1900年1月31日到目标日期的天数
    int days = _daysFrom1900(year, month, day);

    // 查找对应的农历年份和农历日期
    int lunarYear, lunarMonth = 1, lunarDay = 1;
    bool isLeap = false;

    // 查找农历年份
    lunarYear = 1900;
    while (days > 0) {
      int yearDays = _getLunarYearDays(lunarYear);
      if (days > yearDays) {
        days -= yearDays;
        lunarYear++;
      } else {
        break;
      }
    }

    // 查找农历月份和日期
    int i = 1;

    while (i < 15) { // 最多14个月（含闰月）
      int isLeapMonth = _isLeapYear(lunarYear) && i == _getLeapMonth(lunarYear) ? 1 : 0;
      int monthDays = _getLunarMonthDays(lunarYear, i, isLeapMonth);
      
      if (days > monthDays) {
        days -= monthDays;
        i++;
        if (isLeapMonth == 1) {
          i++;
        }
      } else {
        lunarMonth = i;
        if (isLeapMonth == 1) {
          isLeap = true;
        }
        lunarDay = days;
        break;
      }
    }

    // 计算天干地支年
    String lunarYearString = getLunarYearString(lunarYear);
    
    // 计算星期几（0-6）
    int weekday = solarDate.weekday % 7;
    
    return LunarDate(
      lunarYear,
      lunarMonth,
      lunarDay,
      isLeap,
      lunarYearString,
      weekday
    );
  }

  // 获取农历年份的天干地支表示
  static String getLunarYearString(int year) {
    int stemIndex = (year - 4) % 10;
    int branchIndex = (year - 4) % 12;
    
    return '${HEAVENLY_STEMS[stemIndex]}${EARTHLY_BRANCHES[branchIndex]}年';
  }

  // 获取农历年的生肖
  static String getZodiac(int year) {
    int branchIndex = (year - 4) % 12;
    return ZODIAC[branchIndex];
  }

  // 获取农历月份的完整描述
  static String getLunarMonthString(int month, bool isLeap) {
    return isLeap ? '闰${LUNAR_MONTHS[month]}' : LUNAR_MONTHS[month];
  }

  // 获取农历日期的完整描述
  static String getLunarDayString(int day) {
    return LUNAR_DAYS[day];
  }

  // 内部方法：计算从1900年1月31日到指定日期的天数
  static int _daysFrom1900(int year, int month, int day) {
    int totalDays = 0;
    
    // 计算完整年份的天数
    for (int i = 1900; i < year; i++) {
      totalDays += _isLeapYearSolar(i) ? 366 : 365;
    }
    
    // 计算完整月份的天数
    for (int i = 1; i < month; i++) {
      totalDays += _getSolarMonthDays(year, i);
    }
    
    // 加上日期
    totalDays += day;
    
    // 减去1900年1月31日之前的天数（31天）
    totalDays -= 31;
    
    return totalDays;
  }

  // 内部方法：判断是否为公历闰年
  static bool _isLeapYearSolar(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  // 内部方法：获取公历月份的天数
  static int _getSolarMonthDays(int year, int month) {
    switch (month) {
      case 1: case 3: case 5: case 7: case 8: case 10: case 12:
        return 31;
      case 4: case 6: case 9: case 11:
        return 30;
      case 2:
        return _isLeapYearSolar(year) ? 29 : 28;
      default:
        return 0;
    }
  }

  // 内部方法：判断是否为农历闰年
  static bool _isLeapYear(int lunarYear) {
    if (lunarYear < 1900 || lunarYear > 2100) {
      return false; // 超出数据范围，默认为平年
    }
    return (LUNAR_DATA[lunarYear - 1900] & 0x00100000) != 0;
  }

  // 内部方法：获取农历闰年的闰月
  static int _getLeapMonth(int lunarYear) {
    if (lunarYear < 1900 || lunarYear > 2100) {
      return 0; // 超出数据范围，默认为无闰月
    }
    return (LUNAR_DATA[lunarYear - 1900] & 0x000f0000) >> 16;
  }

  // 内部方法：获取农历年份的天数
  static int _getLunarYearDays(int lunarYear) {
    int days = 0;
    int leapMonth = _isLeapYear(lunarYear) ? _getLeapMonth(lunarYear) : 0;
    
    for (int i = 1; i <= 12; i++) {
      days += _getLunarMonthDays(lunarYear, i, 0);
      if (i == leapMonth) {
        days += _getLunarMonthDays(lunarYear, i, 1);
      }
    }
    
    return days;
  }

  // 内部方法：获取农历月份的天数
  static int _getLunarMonthDays(int lunarYear, int month, int isLeap) {
    if (lunarYear < 1900 || lunarYear > 2100) {
      return 30; // 超出数据范围，默认为30天
    }
    
    if (isLeap == 1) {
      month = _getLeapMonth(lunarYear);
    }
    
    return (LUNAR_DATA[lunarYear - 1900] & (0x1f << (month - 1) * 5)) >> ((month - 1) * 5);
  }
  
  // 判断是否为法定节假日
  static bool isHoliday(DateTime date) {
    // 固定的法定节假日
    if (
      // 元旦
      (date.month == 1 && date.day == 1) ||
      // 劳动节
      (date.month == 5 && (date.day == 1 || date.day == 2 || date.day == 3)) ||
      // 国庆节
      (date.month == 10 && (date.day >= 1 && date.day <= 7))
    ) {
      return true;
    }
    
    // 春节（农历正月初一至初三）
    LunarDate lunarDate = solarToLunar(date);
    if (!lunarDate.isLeapMonth && lunarDate.month == 1 && (lunarDate.day >= 1 && lunarDate.day <= 3)) {
      return true;
    }
    
    // 清明节（农历清明前后，这里简化为固定日期4月4日或5日）
    if (date.month == 4 && (date.day == 4 || date.day == 5)) {
      return true;
    }
    
    // 端午节（农历五月初五）
    if (!lunarDate.isLeapMonth && lunarDate.month == 5 && lunarDate.day == 5) {
      return true;
    }
    
    // 中秋节（农历八月十五）
    if (!lunarDate.isLeapMonth && lunarDate.month == 8 && lunarDate.day == 15) {
      return true;
    }
    
    return false;
  }
}

// 农历日期类
class LunarDate {
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;
  final String yearString; // 天干地支年
  final int weekday; // 0-6，0代表周日

  LunarDate(this.year, this.month, this.day, this.isLeapMonth, this.yearString, this.weekday);

  // 获取完整的农历日期描述
  String getFullDescription() {
    String monthStr = LunarUtils.getLunarMonthString(month, isLeapMonth);
    String dayStr = LunarUtils.getLunarDayString(day);
    String zodiac = LunarUtils.getZodiac(year);
    
    return '$yearString$zodiac年 $monthStr$dayStr';
  }

  // 获取简短的农历日期描述
  String getShortDescription() {
    String monthStr = LunarUtils.getLunarMonthString(month, isLeapMonth);
    String dayStr = LunarUtils.getLunarDayString(day);
    
    return '$monthStr$dayStr';
  }

  @override
  String toString() {
    return '农历$year${isLeapMonth ? '闰' : ''}$month月$day日';
  }
}