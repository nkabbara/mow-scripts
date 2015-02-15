# mow-scripts
Scripts used at Motors On Wheels (MoW) to make life easy-ier

## daily-reporter.rb

The DMS (Dealer Management System) at MoW produces reports that are very hard to read. It also doesn't have emailing capabilities. It does support FTP though. This script remedies that by creating nicely formatted emails only displaying useful data points without the clutter.

## mow-service-board-updater.rb

Motors On Wheels Service Department handles inspecting and repairing any cars that require repair before placing them on the market. This scripts helps make sure that things are getting done.

Script looks for cards (cars) in the Unprocessed list in the Service department board. Every card that doesn't have a standard task checklist or Final Inspection checklist will get one added to it.
