#!/bin/bash
#
# Perform git commit size statistics in recently 1 month.

bash_dir=$(cd $(dirname $0);pwd)

# get project list
find /home/gerrit/repositories -name '*.git' -type d | grep -v '\.repo' | grep -v '\<repo\.git' > ${bash_dir}/projects.txt

while read -r project; do
    echo ${project} >> ${bash_dir}/size.txt
    cd ${project}
    # get diff size for each revision
    while read -r rev; do
        # Get how many files was changed.
        tot_file=`git show --pretty=format: --name-only ${rev} | grep -v '^$' | wc -l`

        # Get change size of each file and total sum.
        tot_size=0
        while read -r blob; do
            if [[ ${blob} = "0000000000000000000000000000000000000000" ]]; then
                size=0
            else
                size=`echo ${blob} | git cat-file --batch-check | cut -d ' ' -f3`
            fi
            tot_size=$((${size}+${tot_size}))
        done < <(git diff-tree -r -c -M -C --no-commit-id ${rev} | cut -d ' ' -f4)
        echo "${rev},${tot_file},${tot_size}" >> ${bash_dir}/size.txt
    done < <(git rev-list --all --pretty=oneline --no-merges --since="1 month" | cut -d ' ' -f1)
done < ${bash_dir}/projects.txt