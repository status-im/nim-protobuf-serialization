rm *.proto
curl https://api.github.com/repos/protocolbuffers/protobuf/contents/src/google/protobuf | jq -cr '.[] | select( .name | endswith(".proto")) | .download_url ' | grep -v unit | grep -v test |  xargs -n1 curl -OJ
