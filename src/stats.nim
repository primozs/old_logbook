import os, strutils, options, math, sugar
import pkg/datamancer
import pkg/ggplotnim

type SummaryStats = object
  records_count: int
  flights_count: int
  total_duration: float
  mean_duration: float
  max_duration: float
  total_distance: float
  mean_distance: float
  max_distance: float
  max_alt: int
  max_lift: float
  gliders: seq[string] = @[]

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
      f{int: "year" ~ getYear idx("date", string)},
      f{int: "month" ~ getMonth idx("date", string)}
    )

  let res = processSummary(df)
  echo res

  #by year
  let byYear = df.group_by("year")
  for t, subDf in byYear.groups():
    echo "YEAR: ", t[0][0], ": ", t[0][1].toInt
    echo processSummary(subDf)

  # by year and month
  let byYearMonth = df.group_by(@["year", "month"])
  for t, subDf in byYearMonth.groups():
    echo t
    echo processSummary(subDf)

  # by glider
  let byGlider = df.group_by("glider")
  for t, subDf in byGlider.groups():
    echo $t
    echo processSummary(subDf)
