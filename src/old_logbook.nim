import os, strutils, options, math
import ./csv

type LogbookEntryCsv = object
  takeoff: string
  landing: string
  takeoff_no: int
  duration: string
  distance: Option[int]
  competitors_no: string
  result_place: string
  date: string
  desc: string
  max_alt: Option[int]
  max_lift: Option[float]
  glider: string

type LogbookEntry = object
  takeoff: string
  takeoff_no: int
  landing: string
  duration: int
  distance: Option[int]
  competitors_no: string
  result_place: string
  date: string
  desc: string
  max_alt: Option[int]
  max_lift: Option[float]
  glider: string

type LogbookTandemEntryCsv = object
  count: int
  takeoff: string
  date: string
  date2: string
  time: int

type LogbookEntry2007Csv = object
  count: int
  day: int
  month: int
  year: int
  glider: string
  time: int
  takeoff: string
  description: string

proc cleanNumberString(d: string): string =
  for c in d:
    if c.isDigit:
      result.add c
    elif c == '.':
      result.add "."
    elif c == ',':
      result.add "."

proc dumpHook(d: DumpContext, v: Option[int]) =
  if v.isSome:
    d.data.add $v.get()
  else:
    d.data.add ""

proc dumpHook(d: DumpContext, v: Option[float]) =
  if v.isSome:
    d.data.add $v.get()
  else:
    d.data.add ""

proc parseHook(p: ParseContext, name: string, v: var Option[int]) =
  if name == "distance":
    var d: string
    p.parseHook(name, d)
    let s = cleanNumberString(d)
    let dist = if s == "": none(int) else: some (s.parseFloat()*1000).round.toInt()
    v = dist
  if name == "max_alt":
    var d: string
    p.parseHook(name, d)
    let parts = d.split("-")
    let s = cleanNumberString(parts[0])
    let alt = if s == "": none(int) else: some s.parseInt()
    v = alt

proc parseHook(p: ParseContext, name: string, v: var Option[float]) =
  var d: string
  p.parseHook(name, d)
  let parts = d.split(" ")
  let s = cleanNumberString(parts[0])
  let lift = if s == "": none(float) else: some(s.parseFloat())
  v = lift

proc read2000(): seq[LogbookEntry] =
  let inputFile = "data" / "stari-starti-skupaj.csv"
  let f = open(inputFile, fmRead)
  defer: f.close()
  let data = f.readAll()
  let entries = fromCsv(data, seq[LogbookEntryCsv],
      hasHeader = true)

  for ec in entries:
    let durParts = ec.duration.split(";")

    if durParts.len == 1:
      var e = LogbookEntry()
      e.takeoff = ec.takeoff
      e.takeoff_no = ec.takeoff_no
      e.landing = ec.landing
      e.competitors_no = ec.competitors_no
      e.result_place = ec.result_place
      e.desc = ec.desc
      e.glider = ec.glider
      e.duration = parseInt(durParts[0])
      e.distance = ec.distance
      e.date = ec.date
      e.max_alt = ec.max_alt
      e.max_lift = ec.max_lift
      e.glider = ec.glider
      result.add e
    else:
      for part in durParts:
        var e = LogbookEntry()
        e.takeoff = ec.takeoff
        e.takeoff_no = 1
        e.landing = ec.landing
        e.competitors_no = ec.competitors_no
        e.result_place = ec.result_place
        e.desc = ec.desc
        e.glider = ec.glider
        e.duration = parseInt(part)
        e.distance = ec.distance
        e.date = ec.date
        e.max_alt = ec.max_alt
        e.max_lift = ec.max_lift
        e.glider = ec.glider
        result.add e


proc readTandems(): seq[LogbookEntry] =
  let inputFile = "data" / "starti-tandem.csv"
  let f = open(inputFile, fmRead)
  defer: f.close()
  let data = f.readAll()
  let entries = fromCsv(data, seq[LogbookTandemEntryCsv], hasHeader = true)
  for et in entries:
    var e = LogbookEntry()
    e.takeoff = et.takeoff
    e.takeoff_no = et.count
    e.glider = "Tandem"
    e.duration = et.time
    e.date = et.date2
    result.add e

proc read2007on(): seq[LogbookEntry] =
  let inputFile = "data" / "start-2007-2011_clean.csv"
  let f = open(inputFile, fmRead)
  defer: f.close()
  let data = f.readAll()
  let entries = fromCsv(data, seq[LogbookEntry2007Csv], hasHeader = true)
  for ec in entries:
    let date = $ec.year & "-" & $ec.month & "-" & $ec.day
    var e = LogbookEntry()
    e.takeoff_no = ec.count
    e.date = date
    e.glider = ec.glider
    e.duration = ec.time
    e.takeoff = ec.takeoff
    e.desc = ec.description
    result.add e


proc main() =
  let entries2000 = read2000()
  let entriesTandem = readTandems()
  let entries2007 = read2007on()

  let entries = entries2000 & entriesTandem & entries2007

  let output = "data" / "output.csv"
  let f = open(output, fmWrite)
  defer: f.close()
  f.write(toCsv(entries, hasHeader = true))


when isMainModule:
  main()

