# Windows-Matlab-App

Windows-Desktop (Wine) im Browser mit MATLAB, als Pod-App fuer den DHBW AppStore.

Status: **Machbarkeitsnachweis (Spike)**. Der Workflow `Spike (Wine + MATLAB)` baut das
Image nur lokal auf dem Runner und prueft, ob Wine unter dem Sicherheitskontext der
Plattform laeuft und ob die Windows-Version von MATLAB per `mpm.exe` installiert und
gestartet werden kann. Das Ergebnis steht in der Job-Summary.

MATLAB ist nicht Teil des Images (Lizenz), sondern wird beim ersten Start in das
Wine-Prefix auf dem Storage-Volume installiert. Die Aktivierung erfolgt durch die
Studierenden mit dem MathWorks-Account der Hochschule (Shibboleth).
