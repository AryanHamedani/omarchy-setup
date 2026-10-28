// node test/model-test.js
//
// Every conversion is checked against ICU's Persian calendar, which node
// ships with, so the arithmetic is proven against an independent
// implementation rather than against itself.

const assert = require("assert")
const path = require("path")
const fs = require("fs")
const Model = require("../Model.js")

const root = path.join(__dirname, "..")
const events = {
  national: JSON.parse(fs.readFileSync(path.join(root, "events/national.json"))),
  international: JSON.parse(fs.readFileSync(path.join(root, "events/international.json"))),
  years: { 1405: JSON.parse(fs.readFileSync(path.join(root, "events/1405.json"))) }
}
const english = Object.assign({ titles: JSON.parse(fs.readFileSync(path.join(root, "events/en.json"))) }, events)

let passed = 0
function test(name, fn) {
  fn()
  passed++
  console.log("ok - " + name)
}

const icu = new Intl.DateTimeFormat("en-u-ca-persian-nu-latn", {
  timeZone: "UTC", year: "numeric", month: "numeric", day: "numeric"
})

function icuJalali(ms) {
  const parts = Object.fromEntries(icu.formatToParts(new Date(ms)).map(p => [p.type, p.value]))
  return { year: parseInt(parts.year, 10), month: parseInt(parts.month, 10) - 1, day: parseInt(parts.day, 10) }
}

test("every day from 1300 to 1500 matches ICU", () => {
  let ms = Date.UTC(1921, 2, 21)
  const end = Date.UTC(2121, 2, 21)
  for (; ms < end; ms += 86400000) {
    const d = new Date(ms)
    const j = Model.toJalali(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
    assert.deepStrictEqual(j, icuJalali(ms), d.toISOString())
    const g = Model.toGregorian(j.year, j.month, j.day)
    assert.deepStrictEqual(g, { year: d.getUTCFullYear(), month: d.getUTCMonth(), day: d.getUTCDate() })
  }
})

test("known dates", () => {
  assert.deepStrictEqual(Model.toJalali(2026, 2, 21), { year: 1405, month: 0, day: 1 })
  assert.deepStrictEqual(Model.toJalali(2026, 9, 27), { year: 1405, month: 7, day: 5 })
  assert.deepStrictEqual(Model.toJalali(1979, 1, 11), { year: 1357, month: 10, day: 22 })
})

test("leap years and month lengths", () => {
  assert.strictEqual(Model.isLeapYear(1403), true)
  assert.strictEqual(Model.isLeapYear(1404), false)
  assert.strictEqual(Model.monthLength(1403, 11), 30)
  assert.strictEqual(Model.monthLength(1404, 11), 29)
  assert.strictEqual(Model.monthLength(1404, 0), 31)
  assert.strictEqual(Model.monthLength(1404, 6), 30)
})

test("formats Persian with Persian digits", () => {
  const date = new Date(2026, 9, 27, 14, 5)
  assert.strictEqual(Model.formatJalali(date, "dddd d MMMM HH:mm", "fa"), "سه‌شنبه ۵ آبان ۱۴:۰۵")
  assert.strictEqual(Model.formatJalali(date, "yyyy/MM/dd", "fa"), "۱۴۰۵/۰۸/۰۵")
  assert.strictEqual(Model.formatJalali(date, "h:mm AP", "fa"), "۲:۰۵ ب.ظ")
})

test("formats English with Latin digits", () => {
  const date = new Date(2026, 9, 27, 9, 30)
  assert.strictEqual(Model.formatJalali(date, "dddd d MMMM yyyy HH:mm", "en"), "Tuesday 5 Aban 1405 09:30")
  assert.strictEqual(Model.formatJalali(date, "'Week' d", "en"), "Week 5")
  assert.strictEqual(Model.formatJalali(new Date(2026, 9, 27, 14, 5, 9), "MM/dd HH:mm:ss", "en"), "08/05 14:05:09")
  assert.strictEqual(Model.showsSeconds("MM/dd HH:mm:ss"), true)
  assert.strictEqual(Model.showsSeconds("HH:mm 'ss'"), false)
  assert.strictEqual(Model.formatJalali(date, "ddd d MMM", "en"), "Tue 5 Aba")
  assert.strictEqual(Model.formatJalali(date, "ddd d MMM", "fa"), "سه‌شنبه ۵ آبان")
})

test("format ring walks and wraps", () => {
  const ring = Model.clockFormatRing("dddd HH:mm", "d MMMM yyyy", Model.clockFormats(false))
  assert.strictEqual(Model.nextClockFormat(ring, "dddd HH:mm"), "dddd d MMMM HH:mm")
  assert.strictEqual(Model.nextClockFormat(ring, ring[ring.length - 1]), ring[0])
  assert.strictEqual(Model.nextClockFormat(ring, "custom"), ring[0])
})

test("grid is six Saturday-start weeks covering the month", () => {
  const weeks = Model.monthGrid(1405, 7, 6, "2026-10-27", events)
  assert.strictEqual(weeks.length, 6)
  weeks.forEach(w => {
    assert.strictEqual(w.days.length, 7)
    assert.strictEqual(w.days[0].weekday, 6)
    assert.strictEqual(w.days[6].weekday, 5)
  })
  const inMonth = weeks.flatMap(w => w.days).filter(d => d.inMonth)
  assert.strictEqual(inMonth.length, 30)
  assert.strictEqual(inMonth[0].day, 1)
  assert.strictEqual(weeks.flatMap(w => w.days).filter(d => d.today).length, 1)
})

test("grid honors a Monday start", () => {
  const weeks = Model.monthGrid(1405, 0, 1, "", events)
  weeks.forEach(w => assert.strictEqual(w.days[0].weekday, 1))
})

test("official holidays come from the year's file", () => {
  const nowruz = Model.occasions(events, { year: 1405, month: 0, day: 1 }, { year: 2026, month: 2, day: 21 })
  assert.strictEqual(nowruz.holiday, true)
  assert.ok(nowruz.titles.some(t => t.includes("نوروز")))
  assert.ok(nowruz.titles.some(t => t.includes("فطر")))

  const ashura = Model.occasions(events, { year: 1405, month: 3, day: 4 }, { year: 2026, month: 5, day: 25 })
  assert.strictEqual(ashura.holiday, true)
})

test("years without a file still keep solar holidays", () => {
  const revolution = Model.occasions(events, { year: 1410, month: 10, day: 22 }, { year: 2032, month: 1, day: 11 })
  assert.strictEqual(revolution.holiday, true)
  const plain = Model.occasions(events, { year: 1410, month: 7, day: 3 }, { year: 2031, month: 9, day: 25 })
  assert.strictEqual(plain.holiday, false)
})

test("every occasion has an English title", () => {
  const titles = new Set()
  Object.values(events.national).forEach(m => m.forEach(e => titles.add(e.title)))
  Object.values(events.international).forEach(m => m.forEach(e => titles.add(e.title)))
  ;["1404", "1405", "1406"].forEach(y => {
    const year = JSON.parse(fs.readFileSync(path.join(root, "events", y + ".json")))
    Object.values(year).forEach(d => d.events.forEach(t => titles.add(t)))
  })
  titles.forEach(t => assert.ok(english.titles[t], "untranslated: " + t))
})

test("English titles replace Persian ones", () => {
  const nowruz = Model.occasions(english, { year: 1405, month: 0, day: 1 }, { year: 2026, month: 2, day: 21 })
  assert.deepStrictEqual(nowruz.titles.slice(0, 2), ["Nowruz, the Persian New Year", "Eid al-Fitr"])
})

test("international occasions land on their Gregorian date", () => {
  const christmas = Model.occasions(events, { year: 1405, month: 9, day: 4 }, { year: 2026, month: 11, day: 25 })
  assert.ok(christmas.titles.some(t => t.includes("کریسمس")))
})

test("Fridays are holidays", () => {
  const weeks = Model.monthGrid(1405, 7, 6, "", events)
  weeks.forEach(w => assert.strictEqual(w.days[6].holiday, true))
})

test("year progress runs from Nowruz", () => {
  assert.strictEqual(Model.yearProgressPercent(1405, 0, 1), 0)
  assert.strictEqual(Model.yearProgressPercent(1404, 11, 29), 100)
  assert.strictEqual(Model.dayOfYear(1405, 7, 5), 221)
})

test("week numbers start at Farvardin", () => {
  assert.strictEqual(Model.weekOfYear(1405, 0, 1), 1)
  assert.ok(Model.weekOfYear(1405, 11, 29) >= 52)
})

test("birth years accept Persian digits", () => {
  assert.strictEqual(Model.parseBirthYear("۱۳۷۵", 1405), 1375)
  assert.strictEqual(Model.ageFromBirthYear(1375, 1405), 30)
  assert.strictEqual(Model.parseBirthYear("1410", 1405), 0)
  assert.strictEqual(Model.parseLifeExpectancy("۸۰"), 80)
})

test("week start defaults to Saturday and toggles to Monday", () => {
  assert.strictEqual(Model.normalizedWeekStart(null), 6)
  assert.strictEqual(Model.normalizedWeekStart("monday"), 1)
  assert.strictEqual(Model.toggledWeekStart(6), 1)
  assert.strictEqual(Model.toggledWeekStart(1), 6)
  assert.strictEqual(Model.weekStartSettingName(6), "saturday")
})

test("month stepping crosses years", () => {
  assert.deepStrictEqual(Model.stepMonth(1405, 11, 1), { year: 1406, month: 0 })
  assert.deepStrictEqual(Model.stepMonth(1405, 0, -1), { year: 1404, month: 11 })
  assert.deepStrictEqual(Model.stepMonth(1405, 7, -12), { year: 1404, month: 7 })
})

console.log(passed + " passed")
