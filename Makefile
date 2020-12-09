all: run-update run push

run-update:
	echo updating
	cd /Users/miguel/cvs/COVID-19; git pull --rebase

run: update output//Build/Products/Debug/CovidExtractor
	./output/Build/Products/Debug/CovidExtractor

output//Build/Products/Debug/CovidExtractor: CovidExtractor/CovidData.swift CovidExtractor/Smoothing.swift CovidExtractor/main.swift
	rm -rf output
	mkdir output
	xcodebuild -project CovidExtractor.xcodeproj -scheme CovidExtractor -archivePath `pwd`/output -derivedDataPath `pwd`/output

push: run
	rsync -a -e "ssh -i /Users/miguel/.ssh/empty-password-push-web" /tmp/ind/ miguel@45.55.96.137:web/tirania.org/covid-data/
