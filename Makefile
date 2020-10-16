all: run-update run push

run-update:
	echo updating
	cd /Users/miguel/cvs/COVID-19; git pull --rebase

run: update
	/Users/miguel/DerivedData/CovidExtractor-dphzdfpfhsjopvcfspgeogteompx/Build/Products/Debug/CovidExtractor

push: run
	rsync -a -e "ssh -i /Users/miguel/.ssh/empty-password-push-web" /tmp/ind/ miguel@45.55.96.137:web/tirania.org/covid-data/
