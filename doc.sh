set -ex
rm -rf docs/_docs
v fmt -w farmerbot
pushd farmerbot
v doc -m -f html . -readme -comments -no-timestamp 
popd
mv farmerbot/_docs docs

