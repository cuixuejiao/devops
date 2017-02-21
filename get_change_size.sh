#!/bin/bash
#
# Perform git commit lines statistics in recently 1 month.
# Doesn't including binary files.

bash_dir=$(cd $(dirname $0);pwd)

# get project list
find /home/gerrit/repositories -name '*.git' -type d | grep -v '\.repo' | grep -v '\<repo\.git' \
    > ${bash_dir}/projects.txt

echo "Statistics start at "`date` > ${bash_dir}/lines.txt
while read -r project; do
    echo "${project} " | tr -d '\n' >> ${bash_dir}/lines.txt
    cd ${project} && git log --all --pretty=tformat: --numstat --no-merges --since="1 month" \
        | gawk '{ add+=$1 ; subs+=$2 ; loc+=$1-$2 } END { print add,subs,loc }' \
        >> ${bash_dir}/lines.txt
done < ${bash_dir}/projects.txt
echo "Statistics end at "`date` >> ${bash_dir}/lines.txt