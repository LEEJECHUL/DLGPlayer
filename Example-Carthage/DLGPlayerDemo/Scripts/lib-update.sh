if ! gem spec xcodeproj > /dev/null 2>&1; then
	sudo gem install xcodeproj
fi

if ! brew ls --versions carthage > /dev/null 2>&1; then
	brew install carthage
fi

useclean=false

for i in "$@"
do
case $i in
	--use-clean)
		useclean=true
	;;
esac
done

cd ..

if $useclean ; then
	pod clean
	rm -rf ./Carthage
fi

pod install
# carthage update --no-use-binaries --platform iOS
carthage update --platform ios --no-use-binaries --use-ssh
# carthage update --no-checkout --no-build --no-use-binaries --platform iOS

cd Scripts
ruby carthage_xconfig.rb
