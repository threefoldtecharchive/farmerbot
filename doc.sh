set -ex
rm -rf docs/_docs
v fmt -w farmerbot
pushd farmerbot
v doc -m -f html . -readme -comments -no-timestamp 
popd
mv docs/_docs docs
open docs/index.html

# open https://threefoldfoundation.github.io/dao_research/liqpool/docs/liquidity.html