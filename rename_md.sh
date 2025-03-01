#!/bin/bash

# 遍历当前目录及子目录下的所有.md文件
find . -type f -name "*.md" | while read -r file
do
    # 获取文件名（不含路径）和目录路径
    filename=$(basename "$file")
    dirname=$(dirname "$file")
    
    # 检查文件名是否已经包含(ap)
    if [[ ! "$filename" =~ \(ap\)\.md$ && ! "$filename" =~ \(cs\)\.md$ ]]; then
        # 构建新文件名：将.md替换为(ap).md
        newname="${filename%.md}(ap).md"
        
        # 执行重命名
        mv "$file" "$dirname/$newname"
        echo "Renamed: $file -> $dirname/$newname"
    fi
done