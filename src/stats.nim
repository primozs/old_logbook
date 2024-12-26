# https://github.com/Vindaar/ggplotnim/blob/master/recipes.org#fun-with-elements import os, strutils, options, math, sugar
import os, strutils, sequtils, strformat
import pkg/datamancer
import pkg/ggplotnim

type SummaryStats* = object
  records_count*: int
  flights_count*: int
  total_duration*: float
  mean_duration*: float
  max_duration*: float
  total_distance*: float
  mean_distance*: float
  max_distance*: float
  max_alt*: int
  max_lift*: float
  gliders*: seq[string] = @[]

proc processSummary(df: DataFrame): SummaryStats =
  result.records_count = df.len
  result.flights_count = df["takeoff_no", int].sum()

  let td = df["duration", int].sum
  let totalDuration = if td != 0: td / 60 else: 0

  let md = df["duration", int].mean
  let meanDuration = if md != 0: md / 60 else: 0

  let maxDur = df["duration", int].max
  let maxDuration = if maxDur != 0: maxDur / 60 else: 0

  result.total_duration = totalDuration.round(2)
  result.mean_duration = meanDuration.round(2)
  result.max_duration = maxDuration

  let tDist = df["distance", int].sum
  let totalDist = if tDist != 0: tDist / 1000 else: 0

  let mDist = df["distance", int].mean
  let meanDist = if mDist != 0: mDist / 1000 else: 0

  let maxD = df["distance", int].max
  let maxDist = if maxD != 0: maxD / 1000 else: 0

  result.total_distance = totalDist.round(2)
  result.mean_distance = meanDist.round(2)
  result.max_distance = maxDist

  let maxLift = df["max_lift", float].max
  result.max_lift = maxLift.round(2)

  result.max_alt = df["max_alt", int].max

  var gliders: seq[string]
  for item in df.select("glider").unique("glider"):
    gliders.add $item["glider"]

  result.gliders = gliders

proc cleanDist[T](a: T): T =
  let res = if a > 0: a else: 0
  return res

proc getYear[string](x: string): int =
  let parts = x.split("-")
  return parts[0].parseInt()

proc getMonth[string](x: string): int =
  let parts = x.split("-")
  return parts[1].parseInt()

proc cleanMaxAlt(a: Value): int =
  let res = if a.isNull().toBool() == true: 0 else: a.toInt()
  return res

proc cleanMaxLift(a: Value): float =
  let res = if a.isNull().toBool() == true: 0.0 else: a.toFloat()
  return res

proc processStatsTotals*() =
  var df = readCsv("output" / "logbook.csv")
    .select(
      "takeoff", "date", "takeoff_no", "duration", "distance", "max_alt",
      "max_lift", "glider"
    )
    .arrange("date", order = SortOrder.Ascending)
    .mutate(
      f{int: "distance" ~ cleanDist(idx("distance", int))},
      f{int: "max_alt" ~ cleanMaxAlt(idx("max_alt", Value))},
      f{float: "max_lift" ~ cleanMaxLift(idx("max_lift", Value))},
      f{string: "glider" ~ idx("glider", string).toLower},
      f{int: "year" ~ getYear idx("date", string)},
      f{int: "month" ~ getMonth idx("date", string)}
    )

  let totals = processSummary(df)
  let totalsStr = fmt"""
    {totals.records_count=}
    {totals.flights_count=}

    Duration:
    {totals.total_duration=}
    {totals.mean_duration=}
    {totals.max_duration=}

    Distance:
    {totals.total_distance=}
    {totals.mean_distance=}
    {totals.max_distance=}

    {totals.max_alt=}
    {totals.max_lift=}

    {totals.gliders=}
  """
  let totalsOut = "output" / "totals.txt"
  let tf = open(totalsOut, fmWrite)
  defer: tf.close()
  tf.write(totalsStr)

  #by year
  let byYear = df.group_by("year")
  var years: seq[int] = @[]
  var yDuration: seq[float] = @[]
  var yfCount: seq[int]

  for t, subDf in byYear.groups():
    years.add t[0][1].toInt
    let ps = processSummary(subDf)
    yDuration.add ps.total_duration
    yfCount.add ps.flights_count

  let yearsDf = toDf({
    "Years": years,
    "Duration": yDuration,
    "Flights": yfCount
    })

  yearsDf.writeCsv("output" / "years.csv")
  yearsDf.showBrowser("output" / "years.html")

  ggplot(yearsDf, aes("Years", "Duration", fill = "Flights")) +
    geom_bar(stat = "identity", position = "identity") +
    xlab(rotate = -45.0, margin = 1.75, alignTo = "right") +
    ggsave("output/years.svg")

  # by year and month
  let byYearMonth = df.group_by(@["year", "month"])
  var yearMonths: seq[string] = @[]
  var ymDuration: seq[float] = @[]
  var ymfCount: seq[int]

  var yearMonths1: seq[int] = @[]
  var ymDuration1: seq[float] = @[]
  var ymfCount1: seq[int]

  var prevYear: string
  for t, subDf in byYearMonth.groups():
    let year = $t[0][1]
    let month = $t[1][1]
    let y = year & "-" & month

    yearMonths.add y
    let ps = processSummary(subDf)
    ymDuration.add ps.total_duration
    ymfCount.add ps.flights_count

    if prevYear != year and yearMonths1.len > 0:
      # store
      let monthsDf = toDf({
        "Months": yearMonths1,
        "Duration": ymDuration1,
        "Flights": ymfCount1
        })

      monthsDf.writeCsv("output" / fmt"{prevYear}.csv")
      monthsDf.showBrowser("output" / fmt"{prevYear}.html")
      ggplot(monthsDf, aes("Months", "Duration", fill = "Flights")) +
        geom_bar(stat = "identity", position = "identity") +
        xlab(rotate = -45.0, margin = 1.75, alignTo = "right") +
        ggsave("output" / fmt"{prevYear}.svg")
      # reset
      yearMonths1 = @[]
      ymDuration1 = @[]
      ymfCount1 = @[]
      yearMonths1.add month.parseInt()
      ymDuration1.add ps.total_duration
      ymfCount1.add ps.flights_count
    else:
      yearMonths1.add month.parseInt()
      ymDuration1.add ps.total_duration
      ymfCount1.add ps.flights_count
    prevYear = year

  let yearsMonthsDf = toDf({
    "YearsMonths": yearMonths,
    "Duration": ymDuration,
    "Flights": ymfCount
    })
  # echo yearsMonthsDf

  yearsMonthsDf.writeCsv("output" / "years-months.csv")
  yearsMonthsDf.showBrowser("output" / "years-months.html")

  ggplot(yearsMonthsDf, aes("YearsMonths", "Duration", fill = "Flights")) +
    geom_bar(stat = "identity", position = "identity") +
    xlab(rotate = -45.0, margin = 1.75, alignTo = "right") +
    ggsave("output/years-months.svg", width = 5000, height = 1000)

  # by glider
  let byGlider = df.group_by("glider")
  var gliders: seq[string] = @[]
  var gDuration: seq[float] = @[]
  var gfCount: seq[int]

  for t, subDf in byGlider.groups():
    gliders.add $t[0][1]
    let ps = processSummary(subDf)
    gDuration.add ps.total_duration
    gfCount.add ps.flights_count

  let gliderDf = toDf({
    "Gliders": gliders,
    "Duration": gDuration,
    "Flights": gfCount
    })

  gliderDf.writeCsv("output" / "gliders.csv")
  gliderDf.showBrowser("output" / "gliders.html")

  ggplot(gliderDf, aes("Gliders", "Duration", fill = "Flights")) +
    geom_bar(stat = "identity", position = "identity") +
    xlab(rotate = -45.0, margin = 1.75, alignTo = "right") +
    ggsave("output/gliders.svg")


when isMainModule:
  processStatsTotals()
