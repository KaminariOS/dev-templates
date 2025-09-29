from pathlib import Path

def main() -> None:
    base_dir: Path = Path.cwd()
    gitignore_dir: Path = base_dir / "gitignore"

    for folder in base_dir.iterdir():
        if folder.is_dir() and folder.name != "gitignore":
            # Capitalize the first letter of the folder name
            lang: str = folder.name.capitalize()
            gitignore_file: Path = gitignore_dir / f"{lang}.gitignore"

            if gitignore_file.exists():
                # Read the gitignore file
                content: str = gitignore_file.read_text(encoding="utf-8")
                lines: list[str] = content.splitlines()

                # Ensure ".pre-commit-config.yaml" is appended only once
                if ".pre-commit-config.yaml" not in lines:
                    lines.append(".pre-commit-config.yaml")

                # Write the modified content to a new .gitignore file inside the folder
                target_file: Path = folder / ".gitignore"
                target_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
