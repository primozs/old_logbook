# Package

version       = "0.1.0"
author        = "Primoz Susa"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["old_logbook"]


# Dependencies

requires "nim >= 2.2.0"

requires "tabby >= 0.6.0"
requires "datamancer >= 0.5.0"
requires "ggplotnim >= 0.7.2"