@ECHO OFF 
:: Batch file that calls captureChaptersOnTimer.sh for each story the user has selected.
TITLE Automated RoyalRoad Capture Tool (ARCTurus)

SET gitBashPath="C:\Program Files\Git\bin\bash.exe"
SET storyCaptureHome=C:\Users\bcavanaugh\Documents\sharedGitRepo\storyCapture
SET captureChaptersScript=%storyCaptureHome%\captureChaptersOnTimer.sh
SET captureCommand=%gitBashPath% --login -i -- %captureChaptersScript%

:: TODO: set the result file here?
:: TODO: Determine if the result file has been added to. If it has, show it to the user somehow.

:: TODO: Make wait-time a variable?
%captureCommand% --wait-time='1' --id='/fiction/16946/azarinth-healer' --name='azarinth_healer'
%captureCommand% --wait-time='1' --id='/fiction/11209/the-legend-of-randidly-ghosthound' --name='randidly-ghosthound'
%captureCommand% --wait-time='1' --id='/fiction/36065/sylver-seeker' --name='SilverSeeker' 
%captureCommand% --wait-time='1' --id='/fiction/30396/ideascape-an-adventure-litrpg' --name='ideascape'
%captureCommand% --wait-time='1' --id='/fiction/15521/brian-the-drow-a-worldshapers-realmbreakers-litrpg' --name='brianTheDrow'
%captureCommand% --wait-time='1' --id='/fiction/14167/metaworld-chronicles' --name='metaworldChronicles'
%captureCommand% --wait-time='1' --id='/fiction/12024/the-new-world' --name='theNewWorld' 
%captureCommand% --wait-time='1' --id="/fiction/21410/super-minion" --name="superMinion"
%captureCommand% --wait-time='1' --id="/fiction/36983/tower-of-somnus" --name="towerOfSomnus"
%captureCommand% --wait-time='1' --id='/fiction/6051/is-it-reincarnation-if-im-still-dead' --name='isItReincarnationIfImStillDead'
%captureCommand% --wait-time='1' --id='/fiction/30131/seaborn' --name='seaborn'
%captureCommand% --wait-time='1' --id='/fiction/15935/there-is-no-epic-loot-here-only-puns' --name='noEpicLootJustPuns'
%captureCommand% --wait-time='1' --id='/fiction/45245/warhawks-amnesty' --name='warhawksAmnesty'
%captureCommand% --wait-time='1' --id='/fiction/44815/capes-and-cloaks-a-villains-tale' --name='capesAndCloaksAVilliansTale'
%captureCommand% --wait-time='1' --id='/fiction/33020/blessed-time' --name='blessedTime'
%captureCommand% --wait-time='1' --id='/fiction/43182/rising-world' --name='risingWorld'
%captureCommand% --wait-time='1' --id='/fiction/43181/the-hedge-wizard' --name='hedgeWizard'
%captureCommand% --wait-time='1' --name='WanderingInn' --wandering-inn