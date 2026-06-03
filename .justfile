set shell := ["pwsh", "-NoLogo", "-Command"]

dist:
	Ahk2Exe /in "GoldenDictAutoSearch.ahk" /icon "assets/icon.ico" /out "GoldenDictAutoSearch.exe"

clean:
	rm GoldenDictAutoSearch.exe
