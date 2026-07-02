import argparse
import pyperclip


def map_clipboard_headers(sort_alphabetically=False):
    """Reads spreadsheet header row from clipboard and displays the index mappings."""
    # Get header text from clipboard
    clipboard_data = pyperclip.paste()

    if not clipboard_data.strip():
        print(
            "Your clipboard is empty! Please copy your spreadsheet header row first."
        )
        return

    # Excel/Sheets separates columns by tabs
    headers = [col.strip() for col in clipboard_data.split("\t")]

    # Create a list of tuples containing (header_name, original_index)
    indexed_headers = []
    for idx, header in enumerate(headers):
        display_name = header if header else f"[Blank Column]"
        indexed_headers.append((display_name, idx))

    # Conditionally sort alphabetically by the header name (case-insensitive)
    if sort_alphabetically:
        indexed_headers.sort(key=lambda item: item[0].lower())
        print("\n==================================================")
        print("   DETECTED COLUMNS & INDEXES (ALPHABETICAL)     ")
        print("==================================================")
    else:
        print("\n==================================================")
        print("          DETECTED COLUMNS & INDEXES              ")
        print("==================================================")

    # Print the list with original indices preserved
    for display_name, original_idx in indexed_headers:
        print(f"  {display_name:<35} ---> Index [{original_idx}]")


if __name__ == "__main__":
    # Setup CLI arguments
    parser = argparse.ArgumentParser(
        description="Map clipboard spreadsheet headers to indices."
    )
    # action="store_true" acts as a boolean flag. It is False by default, True if passed.
    parser.add_argument(
        "--sort",
        action="store_true",
        help="Sort the column headers alphabetically instead of original position",
    )
    args = parser.parse_args()

    map_clipboard_headers(sort_alphabetically=args.sort)