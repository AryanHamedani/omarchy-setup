// Pure date and format math for the Jalali clock and its calendar panel.
// Everything here is Qt-free so it can be unit tested under node
// (test/model-test.js), which also cross-checks every conversion against
// ICU's own Persian calendar.
//
// Months are 0-based throughout, matching JS Date and the stock clock, so a
// Jalali { year, month, day } reads the same way a Gregorian one does.

// ---- Calendar conversion. The Jalali year starts at the March equinox, so
//      leap years cannot come from a simple cycle; this is the break-table
//      algorithm used by jalaali-js (MIT), accurate for years -61 to 3177.
var BREAKS = [-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210,
  1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178]

function div(a, b) { return ~~(a / b) }
function mod(a, b) { return a - ~~(a / b) * b }

function jalCal(jy) {
  var gy = jy + 621
  var leapJ = -14
  var jp = BREAKS[0]
  var jump = 0
  for (var i = 1; i < BREAKS.length; i++) {
    var jm = BREAKS[i]
    jump = jm - jp
    if (jy < jm) break
    leapJ = leapJ + div(jump, 33) * 8 + div(mod(jump, 33), 4)
    jp = jm
  }
  var n = jy - jp
  leapJ = leapJ + div(n, 33) * 8 + div(mod(n, 33) + 3, 4)
  if (mod(jump, 33) === 4 && jump - n === 4) leapJ += 1
  var leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150
  var march = 20 + leapJ - leapG
  if (jump - n < 6) n = n - jump + div(jump + 4, 33) * 33
  var leap = mod(mod(n + 1, 33) - 1, 4)
  if (leap === -1) leap = 4
  return { leap: leap, gy: gy, march: march }
}

// Julian day number <-> Gregorian, with a 1-based month on the way in.
function g2d(gy, gm, gd) {
  var d = div((gy + div(gm - 8, 6) + 100100) * 1461, 4) + div(153 * mod(gm + 9, 12) + 2, 5) + gd - 34840408
  return d - div(div(gy + 100100 + div(gm - 8, 6), 100) * 3, 4) + 752
}

function d2g(jdn) {
  var j = 4 * jdn + 139361631
  j = j + div(div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908
  var i = div(mod(j, 1461), 4) * 5 + 308
  var gd = div(mod(i, 153), 5) + 1
  var gm = mod(div(i, 153), 12) + 1
  var gy = div(j, 1461) - 100100 + div(8 - gm, 6)
  return { year: gy, month: gm - 1, day: gd }
}

function isLeapYear(jy) {
  return jalCal(jy).leap === 0
}

// Six 31-day months, five of 30, and an Esfand of 29 or 30.
function monthLength(jy, jm) {
  if (jm < 6) return 31
  if (jm < 11) return 30
  return isLeapYear(jy) ? 30 : 29
}

function daysInYear(jy) {
  return isLeapYear(jy) ? 366 : 365
}

function jalaliToJdn(jy, jm, jd) {
  var r = jalCal(jy)
  var monthOffset = jm < 6 ? jm * 31 : 186 + (jm - 6) * 30
  return g2d(r.gy, 3, r.march) + monthOffset + jd - 1
}

function jdnToJalali(jdn) {
  var gy = d2g(jdn).year
  var jy = gy - 621
  var r = jalCal(jy)
  var k = jdn - g2d(gy, 3, r.march)
  if (k >= 0) {
    if (k <= 185) return { year: jy, month: div(k, 31), day: mod(k, 31) + 1 }
    k -= 186
  } else {
    jy -= 1
    k += 179
    if (r.leap === 1) k += 1
  }
  return { year: jy, month: 6 + div(k, 30), day: mod(k, 30) + 1 }
}

function toJalali(gy, gm, gd) {
  return jdnToJalali(g2d(gy, gm + 1, gd))
}

function toGregorian(jy, jm, jd) {
  return d2g(jalaliToJdn(jy, jm, jd))
}

function jalaliForDate(date) {
  return toJalali(date.getFullYear(), date.getMonth(), date.getDate())
}

// Stable "yyyy-MM-dd" Gregorian identity for a day, so a grid cell can be
// compared against today without dragging Date objects through bindings.
function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
}

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

// ---- Names. English is the default, using the transliterations printed on
//      bilingual Iranian calendars; Persian is the alternative.
var MONTHS = {
  fa: ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
       "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"],
  en: ["Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar",
       "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand"]
}

// Indexed by JS weekday, Sunday first.
var WEEKDAYS = {
  fa: ["یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه"],
  en: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
}

var WEEKDAY_SHORT = {
  fa: ["ی", "د", "س", "چ", "پ", "ج", "ش"],
  en: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
}

var MERIDIEM = {
  fa: ["ق.ظ", "ب.ظ"],
  en: ["AM", "PM"]
}

var GREGORIAN_MONTHS = ["January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"]

// The panel's own words, in the same two languages as the dates.
var STRINGS = {
  fa: {
    born: "تولد", liveTo: "تا سن", life: "عمر", year: "سال", week: "ه",
    mementoMori: "یادت باشد", backToToday: "بازگشت به امروز", startWeeksOn: "شروع هفته از ",
    previousMonth: "ماه قبل", nextMonth: "ماه بعد", noOccasions: "مناسبتی ثبت نشده", more: "و %1 مناسبت دیگر"
  },
  en: {
    born: "BORN", liveTo: "LIVE TO", life: "LIFE", year: "year", week: "W",
    mementoMori: "Memento Mori", backToToday: "Back to today", startWeeksOn: "Start weeks on ",
    previousMonth: "Previous month", nextMonth: "Next month", noOccasions: "No occasions", more: "and %1 more"
  }
}

function text(key, language) {
  return STRINGS[normalizedLanguage(language)][key] || ""
}

function normalizedLanguage(value) {
  return String(value || "").toLowerCase() === "fa" ? "fa" : "en"
}

function monthName(month, language) {
  return MONTHS[normalizedLanguage(language)][((month % 12) + 12) % 12]
}

function weekdayName(weekday, language) {
  return WEEKDAYS[normalizedLanguage(language)][weekday]
}

function weekdayShort(weekday, language) {
  return WEEKDAY_SHORT[normalizedLanguage(language)][weekday]
}

// Persian digits, and the Persian percent sign, for Persian text. Applied to whole strings so a format's
// literal numbers come out in the same script as the date around them.
function localizeDigits(text, language) {
  var s = String(text)
  if (normalizedLanguage(language) !== "fa") return s
  return s
    .replace(/[0-9]/g, function(d) { return String.fromCharCode(0x06F0 + Number(d)) })
    .replace(/%/g, "٪")
}

// ---- Bar label formats. The tokens mirror Qt's date format but name the
//      Jalali day, month, and year, since Qt has no Jalali formatter of its
//      own. Quoted runs are literal, as they are in Qt.
//
//   d dd       day of month        ddd dddd   weekday, short and long
//   M MM       month number        MMM MMMM   month name, short and long
//   yy yyyy    year
//   H HH h hh  hour                mm ss  minute, second
//   AP         AM/PM marker
var FORMAT_TOKENS = /'[^']*'|dddd|ddd|dd|d|MMMM|MMM|MM|M|yyyy|yy|HH|H|hh|h|mm|ss|AP|ap/g

function formatJalali(date, format, language) {
  var lang = normalizedLanguage(language)
  var j = jalaliForDate(date)
  var hours = date.getHours()
  var hours12 = hours % 12 === 0 ? 12 : hours % 12
  var out = String(format).replace(FORMAT_TOKENS, function(token) {
    if (token.charAt(0) === "'") return token.length > 2 ? token.slice(1, -1) : "'"
    switch (token) {
      case "dddd": return weekdayName(date.getDay(), lang)
      case "ddd": return shortName(weekdayName(date.getDay(), lang), lang)
      case "dd": return pad2(j.day)
      case "d": return String(j.day)
      case "MMMM": return monthName(j.month, lang)
      case "MMM": return shortName(monthName(j.month, lang), lang)
      case "MM": return pad2(j.month + 1)
      case "M": return String(j.month + 1)
      case "yyyy": return String(j.year)
      case "yy": return pad2(j.year % 100)
      case "HH": return pad2(hours)
      case "H": return String(hours)
      case "hh": return pad2(hours12)
      case "h": return String(hours12)
      case "mm": return pad2(date.getMinutes())
      case "ss": return pad2(date.getSeconds())
      case "AP":
      case "ap": return MERIDIEM[lang][hours < 12 ? 0 : 1]
    }
    return token
  })
  return localizeDigits(out, lang)
}

// Three letters in English, the way Qt shortens names; Persian names are
// never abbreviated, so they stay whole.
function shortName(name, language) {
  return normalizedLanguage(language) === "en" ? name.substr(0, 3) : name
}

// Right-clicking the clock walks these in order and writes the result back to
// shell.json, the same contract as the stock clock.
var CLOCK_FORMATS = [
  "dddd HH:mm",
  "dddd d MMMM HH:mm",
  "d MMMM HH:mm",
  "HH:mm",
  "h:mm AP",
  "d MMMM yyyy",
  "yyyy/MM/dd HH:mm"
]

var VERTICAL_CLOCK_FORMATS = [
  "HH\n—\nmm",
  "h\n—\nmm\nAP",
  "d\nMM\nyy",
  "HH\nmm"
]

// Ticking every second costs a redraw a second, so only a label that shows
// seconds asks for it.
function showsSeconds(format) {
  return /ss/.test(String(format).replace(/'[^']*'/g, ""))
}

function clockFormats(vertical) {
  return vertical ? VERTICAL_CLOCK_FORMATS.slice() : CLOCK_FORMATS.slice()
}

// The presets in a fixed order, plus the configured alternate and current
// format when they are something else, so cycling walks rather than bounces.
function clockFormatRing(configured, configuredAlt, presets) {
  var ring = []
  var candidates = (presets || []).concat([configuredAlt, configured])
  for (var i = 0; i < candidates.length; i++) {
    var format = String(candidates[i] === undefined || candidates[i] === null ? "" : candidates[i])
    if (format === "" || ring.indexOf(format) !== -1) continue
    ring.push(format)
  }
  return ring.length > 0 ? ring : ["HH:mm"]
}

function nextClockFormat(ring, current) {
  if (!ring || ring.length === 0) return ""
  var index = ring.indexOf(String(current === undefined || current === null ? "" : current))
  return ring[(index + 1) % ring.length]
}

// ---- Occasions. Three sources, merged per day:
//
//   national       fixed solar dates: Nowruz, Yalda, Mehregan, ...
//   international  fixed Gregorian dates: Christmas, World Teachers' Day, ...
//   years[jy]      time.ir's official list for that year: the lunar
//                  religious occasions, and which days are holidays
//
// The sources are in Persian; `titles` maps each one to English, and is
// left out when the panel speaks Persian.
//
// Lunar dates are fixed each year by moon sighting, so no formula reproduces
// the official calendar; a year without its file still shows its solar
// occasions and holidays, and simply leaves the lunar ones out rather than
// guessing them a day off. bin/fetch-events adds a year.
var EMPTY_EVENTS = { national: {}, international: {}, years: {} }

// A missing or broken file is an empty one: the grid still draws, it just
// has less to say.
function parseEvents(text) {
  try {
    var parsed = JSON.parse(String(text || ""))
    return parsed && typeof parsed === "object" ? parsed : {}
  } catch (e) {
    return {}
  }
}

// [[1405, text], ...] -> { "1405": {...} }, leaving out years with no file,
// so their solar holidays still come from the national list.
function eventYears(pairs) {
  var years = {}
  for (var i = 0; i < pairs.length; i++) {
    var text = String(pairs[i][1] || "")
    if (text !== "") years[String(pairs[i][0])] = parseEvents(text)
  }
  return years
}

function occasions(events, j, g) {
  var source = events || EMPTY_EVENTS
  var titles = []
  var holiday = false

  var national = (source.national || {})[pad2(j.month + 1)] || []
  for (var i = 0; i < national.length; i++) {
    if (national[i].day !== j.day) continue
    titles.push(national[i].title)
    holiday = holiday || national[i].holiday === true
  }

  var year = (source.years || {})[String(j.year)]
  if (year) {
    var official = year[pad2(j.month + 1) + "-" + pad2(j.day)]
    holiday = !!(official && official.holiday)
    if (official) titles = titles.concat(official.events || [])
  }

  var international = (source.international || {})[pad2(j.month + 1)] || []
  var gregorianDate = GREGORIAN_MONTHS[g.month] + " " + g.day
  for (var k = 0; k < international.length; k++)
    if (international[k].date === gregorianDate) titles.push(international[k].title)

  var english = source.titles
  if (english) titles = titles.map(function(title) { return english[title] || title })
  return { holiday: holiday, titles: titles }
}

// ---- Year progress, measured in the Jalali year: Nowruz reads 0% and the
//      last day of Esfand reads 100%.
function dayOfYear(jy, jm, jd) {
  return jalaliToJdn(jy, jm, jd) - jalaliToJdn(jy, 0, 1) + 1
}

function yearProgress(jy, jm, jd) {
  return Math.max(0, Math.min(1, (dayOfYear(jy, jm, jd) - 1) / daysInYear(jy)))
}

function yearProgressPercent(jy, jm, jd) {
  return Math.round(yearProgress(jy, jm, jd) * 100)
}

// Memento mori. The default span is a round number rather than anything from
// an actuarial table: the point of the bar is the reminder, not the
// arithmetic, and whoever wants a different number can say so.
var DEFAULT_LIFE_EXPECTANCY = 90

// A Jalali birth year rather than an age, so the bar keeps counting on its
// own instead of going stale the moment it is entered. 0 means "not set",
// which is also what a blank, malformed, future, or implausible year means.
function parseBirthYear(value, currentYear) {
  var now = Math.round(Number(currentYear))
  if (!isFinite(now)) return 0
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  text = text.replace(/[۰-۹]/g, function(d) { return String(d.charCodeAt(0) - 0x06F0) })
  if (!/^\d{4}$/.test(text)) return 0
  var year = parseInt(text, 10)
  if (!isFinite(year) || year > now || year < now - 120) return 0
  return year
}

function ageFromBirthYear(birthYear, currentYear) {
  var born = parseBirthYear(birthYear, currentYear)
  if (born <= 0) return 0
  return Math.round(Number(currentYear)) - born
}

function parseAge(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return 0
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 120) return 0
  return years
}

function parseLifeExpectancy(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  text = text.replace(/[۰-۹]/g, function(d) { return String(d.charCodeAt(0) - 0x06F0) })
  if (!/^\d+$/.test(text)) return DEFAULT_LIFE_EXPECTANCY
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 150) return DEFAULT_LIFE_EXPECTANCY
  return years
}

function lifeProgress(age, expectancy) {
  var years = parseAge(age)
  var span = parseLifeExpectancy(expectancy)
  if (years <= 0 || span <= 0) return 0
  return Math.max(0, Math.min(1, years / span))
}

function lifeProgressPercent(age, expectancy) {
  return Math.round(lifeProgress(age, expectancy) * 100)
}

// ---- Week start. Weekday indices match JS Date.getDay() and QML's
//      Locale.Sunday…Locale.Saturday. Iran starts the week on Saturday, so
//      that is the default whatever the system locale says.
var WEEKDAY_KEYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

function normalizedWeekStart(value) {
  if (typeof value === "number" && isFinite(value)) return ((Math.round(value) % 7) + 7) % 7
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "").toLowerCase()
  for (var i = 0; i < WEEKDAY_KEYS.length; i++)
    if (text !== "" && (WEEKDAY_KEYS[i] === text || WEEKDAY_KEYS[i].substr(0, 3) === text)) return i
  return 6
}

function weekStartSettingName(index) {
  return WEEKDAY_KEYS[normalizedWeekStart(index)]
}

// The toggle flips between the two conventions people actually switch
// between: Iran's Saturday, and the Monday of most calendars abroad.
function toggledWeekStart(index) {
  return normalizedWeekStart(index) === 6 ? 1 : 6
}

function weekdayOrder(weekStart) {
  var start = normalizedWeekStart(weekStart)
  var out = []
  for (var i = 0; i < 7; i++) out.push((start + i) % 7)
  return out
}

// JDN 0 was a Monday, so (jdn + 1) % 7 is the JS weekday.
function weekdayOfJdn(jdn) {
  return (jdn + 1) % 7
}

// Week of the Jalali year, as printed on Iranian calendars: Saturday-start,
// with the week holding 1 Farvardin as week one. Rows are numbered by their
// Friday, so a Monday-start row still names the week it mostly belongs to.
function weekOfYear(jy, jm, jd) {
  var first = jalaliToJdn(jy, 0, 1)
  var leading = (weekdayOfJdn(first) + 1) % 7
  return Math.floor((jalaliToJdn(jy, jm, jd) - first + leading) / 7) + 1
}

// Everything the panel shows about one day, in both calendars.
function dayCell(jdn, events, todayKey) {
  var j = jdnToJalali(jdn)
  var g = d2g(jdn)
  var weekday = weekdayOfJdn(jdn)
  var key = dateKey(g.year, g.month, g.day)
  var occasion = occasions(events, j, g)
  return {
    key: key,
    year: j.year,
    month: j.month,
    day: j.day,
    gregorianYear: g.year,
    gregorianMonth: g.month,
    gregorianDay: g.day,
    weekday: weekday,
    inMonth: true,
    weekend: weekday === 5,
    holiday: weekday === 5 || occasion.holiday,
    occasions: occasion.titles,
    today: key === String(todayKey || "")
  }
}

function dayForDate(date, events) {
  var key = keyForDate(date)
  return dayCell(g2d(date.getFullYear(), date.getMonth() + 1, date.getDate()), events, key)
}

// "سه‌شنبه ۵ آبان ۱۴۰۵" over "27 October 2026": the heading of the occasions
// list for whichever day it describes.
function dayTitle(cell, language) {
  var lang = normalizedLanguage(language)
  return localizeDigits(weekdayName(cell.weekday, lang) + " " + cell.day + " " + monthName(cell.month, lang) + " " + cell.year, lang)
}

function gregorianTitle(cell) {
  return cell.gregorianDay + " " + GREGORIAN_MONTHS[cell.gregorianMonth] + " " + cell.gregorianYear
}

// ---- Month grid. Always six rows of seven days, so the popup is exactly as
//      tall in Esfand as it is in Farvardin. Cells carry both calendars: the
//      Jalali day is what the grid shows, the Gregorian day is the small
//      figure beside it, and the Gregorian key is today's identity. Walked in
//      day numbers, so no wall clock or DST gap is ever involved.
function monthGrid(jy, jm, weekStart, todayKey, events) {
  var start = normalizedWeekStart(weekStart)
  var first = jalaliToJdn(jy, jm, 1)
  var cursor = first - (weekdayOfJdn(first) - start + 7) % 7
  var today = String(todayKey || "")
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    var friday = null
    for (var d = 0; d < 7; d++) {
      var cell = dayCell(cursor++, events, today)
      cell.inMonth = cell.month === jm && cell.year === jy
      if (cell.weekend) friday = cell
      days.push(cell)
    }
    var anchor = friday || days[0]
    weeks.push({
      week: weekOfYear(anchor.year, anchor.month, anchor.day),
      days: days
    })
  }
  return weeks
}

function stepMonth(jy, jm, delta) {
  var total = jy * 12 + jm + Number(delta)
  return { year: Math.floor(total / 12), month: ((total % 12) + 12) % 12 }
}

if (typeof module !== "undefined") {
  module.exports = {
    toJalali: toJalali,
    toGregorian: toGregorian,
    jalaliForDate: jalaliForDate,
    isLeapYear: isLeapYear,
    monthLength: monthLength,
    daysInYear: daysInYear,
    dateKey: dateKey,
    keyForDate: keyForDate,
    monthName: monthName,
    weekdayName: weekdayName,
    weekdayShort: weekdayShort,
    localizeDigits: localizeDigits,
    formatJalali: formatJalali,
    showsSeconds: showsSeconds,
    clockFormats: clockFormats,
    clockFormatRing: clockFormatRing,
    nextClockFormat: nextClockFormat,
    occasions: occasions,
    parseEvents: parseEvents,
    eventYears: eventYears,
    text: text,
    dayForDate: dayForDate,
    dayTitle: dayTitle,
    gregorianTitle: gregorianTitle,
    dayOfYear: dayOfYear,
    yearProgress: yearProgress,
    yearProgressPercent: yearProgressPercent,
    parseBirthYear: parseBirthYear,
    ageFromBirthYear: ageFromBirthYear,
    parseAge: parseAge,
    parseLifeExpectancy: parseLifeExpectancy,
    lifeProgress: lifeProgress,
    lifeProgressPercent: lifeProgressPercent,
    normalizedWeekStart: normalizedWeekStart,
    weekStartSettingName: weekStartSettingName,
    toggledWeekStart: toggledWeekStart,
    weekdayOrder: weekdayOrder,
    weekOfYear: weekOfYear,
    monthGrid: monthGrid,
    stepMonth: stepMonth
  }
}
