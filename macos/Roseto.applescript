-- Roseto.app – Droplet für den Finder.
-- PowerPC-Programme (oder .dmg/.sit/.pkg) auf das Symbol ziehen -> sie starten
-- im PowerPC-Mac. Installations-Images (.iso/.cdr/.toast) richten einen neuen
-- PowerPC-Mac ein.

on rosetoCmd()
	return quoted form of (POSIX path of (path to me) & "Contents/Resources/roseto/bin/roseto")
end rosetoCmd

on runRoseto(args)
	try
		return do shell script rosetoCmd() & " " & args & " 2>&1"
	on error errMsg
		display dialog "Roseto meldet einen Fehler:" & return & return & errMsg buttons {"OK"} default button 1 with icon stop with title "Roseto"
		error number -128
	end try
end runRoseto

on chooseProfile(promptText)
	set picked to choose from list {"tiger  – Mac OS X 10.4 Tiger", "leopard – Mac OS X 10.5 Leopard", "panther – Mac OS X 10.3 Panther", "os9  – Mac OS 9.2"} with title "Roseto" with prompt promptText default items {"tiger  – Mac OS X 10.4 Tiger"}
	if picked is false then error number -128
	return first word of (item 1 of picked)
end chooseProfile

on open theItems
	set appItems to {}
	repeat with anItem in theItems
		set p to POSIX path of anItem
		if p ends with "/" and length of p > 1 then set p to text 1 thru -2 of p
		set lowerP to do shell script "printf '%s' " & quoted form of p & " | tr '[:upper:]' '[:lower:]'"
		if lowerP ends with ".iso" or lowerP ends with ".cdr" or lowerP ends with ".toast" then
			set prof to chooseProfile("Welches System ist auf diesem Installations-Image?")
			set out to runRoseto("--profile " & prof & " setup " & quoted form of p)
			display dialog out buttons {"OK"} default button 1 with title "Roseto – Einrichtung"
		else
			set end of appItems to quoted form of p
		end if
	end repeat
	if (count of appItems) > 0 then
		set AppleScript's text item delimiters to " "
		set argList to appItems as text
		set AppleScript's text item delimiters to ""
		set out to runRoseto("run " & argList)
		display notification out with title "Roseto"
	end if
end open

on run
	set actions to {"PowerPC-Programm auswählen und starten …", "PowerPC-Mac starten", "Status anzeigen", "Gast-Werkzeuge-CD einlegen", "Hosts-Einträge bearbeiten (MSN-Server)", "PowerPC-Mac sofort beenden"}
	set picked to choose from list actions with title "Roseto" with prompt "Roseto – PowerPC-Programme auf Apple Silicon." & return & "Tipp: Programme einfach auf das Roseto-Symbol ziehen." default items {item 1 of actions}
	if picked is false then return
	set picked to item 1 of picked
	if picked is item 1 of actions then
		set f to choose file with prompt "PowerPC-Programm, Installer oder Archiv wählen:" with showing package contents
		open {f}
	else if picked is item 2 of actions then
		set out to runRoseto("start")
		if out is not "" then display notification out with title "Roseto"
	else if picked is item 3 of actions then
		display dialog runRoseto("status") buttons {"OK"} default button 1 with title "Roseto – Status"
	else if picked is item 4 of actions then
		display dialog runRoseto("tools") buttons {"OK"} default button 1 with title "Roseto – Gast-Werkzeuge"
	else if picked is item 5 of actions then
		runRoseto("hosts list")
		do shell script "open -e \"$HOME/.roseto/hosts\""
	else if picked is item 6 of actions then
		runRoseto("stop --force")
	end if
end run
