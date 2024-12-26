import ./stats
import ./merge

proc main() =
  mergeOldCsvFiles()
  processStatsTotals()

when isMainModule:
  main()

