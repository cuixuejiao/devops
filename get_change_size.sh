#!/bin/bash
#
# Perform git commit change lines statistics in recently 1 month.
# Doesn't including binary files.

bash_dir=$(cd $(dirname $0);pwd)

# get project list
find /home/gerrit/repositories -name '*.git' -type d | grep -v '\.repo' | grep -v '\<repo\.git' \
    > ${bash_dir}/projects.txt

echo "Statistics start at "`date` > ${bash_dir}/lines.txt
while read -r project; do
    cd ${project}
    # Get changed lines for each revision.
    while read -r rev; do
        lines=`cd ${project} && git log -1 ${rev} --pretty=tformat: --numstat \
            | gawk '{add+=$1 ; subs+=$2 ; loc+=$1-$2} END {print add,subs,loc}'`
        echo "${project} ${rev} ${lines}" >> ${bash_dir}/lines.txt
    done < <(git rev-list --all --oneline --no-merges --since="1 month" | cut -d ' ' -f1)
done < ${bash_dir}/projects.txt
echo "Statistics end at "`date` >> ${bash_dir}/lines.txt