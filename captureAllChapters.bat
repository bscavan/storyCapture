@ECHO OFF 
:: Batch file that calls captureChaptersOnTimer.sh for each story the user has selected.
TITLE Automated RoyalRoad Capture Tool (ARCTurus)

SET gitBashPath="C:\Program Files\Git\bin\bash.exe"
SET storyCaptureHome=C:\Users\bcavanaugh\Documents\sharedGitRepo\storyCapture
SET captureChaptersScript=%storyCaptureHome%\captureChaptersOnTimer.sh
SET captureCommand=%gitBashPath% --login -i -- %captureChaptersScript%

:: TODO: Make wait-time a variable?
%captureCommand% --wait-time='86400' --id='/fiction/16946/azarinth-healer' --name='azarinth_healer'
%captureCommand% --wait-time='86400' --id='/fiction/11209/the-legend-of-randidly-ghosthound' --name='randidly-ghosthound'
%captureCommand% --wait-time='86400' --id='/fiction/10073/the-wandering-inn' --name='wanderingInn'
%captureCommand% --wait-time='86400' --id='/fiction/36065/sylver-seeker' --name='SilverSeeker' 
%captureCommand% --wait-time='86400' --id='/fiction/30396/ideascape-an-adventure-litrpg' --name='ideascape'
%captureCommand% --wait-time='86400' --id='/fiction/15521/brian-the-drow-a-worldshapers-realmbreakers-litrpg' --name='brianTheDrow'
%captureCommand% --wait-time='86400' --id='/fiction/14167/metaworld-chronicles' --name='metaworldChronicles'
%captureCommand% --wait-time='86400' --name='theNewWorld' --id='/fiction/12024/the-new-world'
%captureCommand% --wait-time='86400' --id="/fiction/21410/super-minion" --name="superMinion"
%captureCommand% --wait-time='86400' --id="/fiction/36983/tower-of-somnus" --name"towerOfSomnus"
%captureCommand% --wait-time='86400' --id='/fiction/6051/is-it-reincarnation-if-im-still-dead' --name='isItReincarnationIfImStillDead'
