#!/bin/bash
git init
git config --global --add safe.directory /github/workspace
git config --global core.pager "less -FRSX"

before=$(jq .before ${GITHUB_EVENT_PATH} | tr -d '"')
after=${GITHUB_SHA} | tr -d '"'

git fetch origin ${before} --depth=1

echo "Checking for changes"
echo ""
res=""
if [[ ${GITHUB_EVENT_NAME} == "pull_request" ]]; then
    echo "On pull request"
    res=$(git --no-pager diff --name-status origin/${GITHUB_BASE_REF} ${INPUT_FILESLOCATION})
    #Find warnings
    #bash ./MarkdownToConfluence/convert_all.sh men som bare kun converter og smider warnings uden at uploade
elif [[ ${GITHUB_EVENT_NAME} == "push" ]]; then
    echo "On push"
    res=$(git --no-pager diff --name-status ${before}..${after} -- ${INPUT_FILESLOCATION})

    if [[ $res != "" ]]; then
    ReMoFilesArrOLD=()
    ReMoFilesArrNEW=()
    delFilesArr=()
    changedFilesArr=()
    while IFS=$'\t' read -r -a tmp ; do
        # Renamed or moved files
        if [[ ${tmp[0]} = R* ]]; then
            echo "---Renamed/Moved---"
            echo "from ${tmp[1]}"
            echo "to ${tmp[2]}"
            #TODO: rework, måske indsæt til et array som movedArr+=("${tmp[1]}", ${tmp[2]})
            ReMoFilesArrOLD+=("${tmp[1]}")
            ReMoFilesArrNEW+=("${tmp[2]}")
            #Skal kalde update med gamle og ny sti
        # Modified files
        elif [[ ${tmp[0]} = M* ]]; then
            echo "---Modified---"
            echo ${tmp[1]}
            changedFilesArr+=("${tmp[1]}")
        # Deleted files
        elif [[ ${tmp[0]} = D* ]]; then
            echo "---Deleted---"
            echo ${tmp[1]}
            delFilesArr+=("${tmp[1]}")
        # Added files
        elif [[ ${tmp[0]} = A* ]]; then
            echo "---Added---"
            echo ${tmp[1]}
            changedFilesArr+=("${tmp[1]}")
        elif [[ ${tmp[1]} || ${tmp[2]} == *settings.json ]]; then
            echo "Changes to settings.json found, converting all files."
            bash ./MarkdownToConfluence/convert_all.sh
        else
            echo "---Other changes---"
            echo ${tmp[@]}
        fi
    done <<< $res
    else
        echo "There are no changes to documentation"
    fi
    
    if [[ ${#changedFilesArr[@]} -eq 0 ]]; then
        echo "Modified or changed files"
        for file in "${changedFilesArr[@]}"
        do
            if [[ $file == *.md ]]; then
                bash ./MarkdownToConfluence/convert.sh "$file"
            else
                echo "Couldn't upload ${file}"
            fi
        done
    fi

    if [[ ${#delFilesArr[@]} -eq 0 ]]; then
        echo "Deleted files"
        for i in "${delFilesArr[@]}"
        do
            if [[ $file == *.md ]]; then
                # python3 ./MarkdownToConfluence/confluence/delete_content.py $file
                echo "Tried deleting page ${file}"
            elif [[ $file == *settings.json ]]; then
                bash ./MarkdownToConfluence/convert_all.sh
            else
                echo "${file} might not have been deleted"
            fi
        done
    fi

    if [[ ${#ReMoFilesArrOLD[@]} -eq 0 ]]; then
        echo "Renamed/Moved files"
        for i in "${ReMoFilesArrOLD[@]}"
        do
            if [[ $file == *.md ]]; then
                # python3 ./MarkdownToConfluence/confluence/update_content.py $ReMoFilesArrOLD[i] ReMoFilesArrNEW[i]
                echo "Tried moving page ${file}"
            elif [[ $file == *settings.json ]]; then
                bash ./MarkdownToConfluence/convert_all.sh
            else
                echo "${file} might not have been moved/renamed"
            fi
        done
    fi
fi