set wowdir=C:\Program Files (x86)\World of Warcraft
set addonsdir=%wowdir%\_retail_\Interface\Addons
set tdir=%addonsdir%\WhoTracker
xcopy /i /y WhoTracker.* "%tdir%"
