import os
import re

def clean_swift_comments(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".swift") and not "build" in root:
                filepath = os.path.join(root, file)
                with open(filepath, 'r') as f:
                    lines = f.readlines()

                new_lines = []
                in_doc_comment_block = False
                doc_comment_count = 0

                for line in lines:
                    stripped = line.strip()

                    if stripped.startswith("// MARK:"):
                        new_lines.append(line)
                        continue

                    if stripped.startswith("///"):
                        if not in_doc_comment_block:
                            in_doc_comment_block = True
                            doc_comment_count = 1
                            new_lines.append(line)
                        else:
                            doc_comment_count += 1
                        continue
                    else:
                        in_doc_comment_block = False
                        doc_comment_count = 0

                    if stripped.startswith("//"):
                        continue


                    new_lines.append(line)

                with open(filepath, 'w') as f:
                    f.writelines(new_lines)

clean_swift_comments("/Users/kinclarkperez/Desktop/Swift/Macoshackathon/Perch")
print("Finished cleaning comments.")
