#!/usr/bin/env python3
"""
Simple ASCII phylogenetic tree viewer with optional clade filtering.

Usage:
    # View entire tree (phylogram - with branch lengths)
    python tree_view.py tree.newick

    # View as cladogram (topology only, equal branch lengths)
    python tree_view.py --cladogram tree.newick

    # View only the clade containing specific samples
    python tree_view.py tree.newick Barcode-7-Scaffolds.fasta Barcode-8-Scaffolds.fasta

    # Cladogram view of a clade (best for tight clusters)
    python tree_view.py --cladogram tree.newick Barcode-8-Scaffolds.fasta Barcode-9-Scaffolds.fasta

Author: Generated for Gingr phylogenetic analysis
"""

import sys
from Bio import Phylo
from io import StringIO


def get_ascii_tree(tree_file, query_samples=None):
    """
    Load tree and optionally filter to clade containing query samples.

    Args:
        tree_file: Path to Newick tree file
        query_samples: Optional list of sample names to filter to

    Returns:
        Tuple of (Phylo tree object, full tree object for height comparison)
    """
    # Load full tree (keep separate copy for height comparison)
    full_tree = Phylo.read(tree_file, "newick")
    tree = Phylo.read(tree_file, "newick")

    if query_samples:
        # Find query leaves
        query_leaves = []
        all_leaf_names = [leaf.name for leaf in tree.get_terminals()]

        for query in query_samples:
            if query not in all_leaf_names:
                print(f"ERROR: Sample '{query}' not found in tree", file=sys.stderr)
                print(f"Available samples:", file=sys.stderr)
                for name in sorted(all_leaf_names):
                    print(f"  - {name}", file=sys.stderr)
                sys.exit(1)

        # Collect matching leaves
        for leaf in tree.get_terminals():
            if leaf.name in query_samples:
                query_leaves.append(leaf)

        # Find smallest clade containing all query samples
        if len(query_leaves) == 1:
            # For single sample, get its parent to show context
            parent = tree.get_path(query_leaves[0])[-2]
            tree = parent
        else:
            # Find common ancestor
            common_ancestor = tree.common_ancestor(query_leaves)
            tree = common_ancestor

    return tree, full_tree


def get_tree_height(tree):
    """
    Calculate the maximum root-to-leaf distance (tree height).

    Args:
        tree: Phylo tree object

    Returns:
        Maximum distance from root to any leaf
    """
    leaves = tree.get_terminals()
    if not leaves:
        return 0.0

    # Get root
    root = tree.root

    # Calculate distance to each leaf and find maximum
    max_distance = 0.0
    for leaf in leaves:
        distance = tree.distance(root, leaf)
        if distance > max_distance:
            max_distance = distance

    return max_distance


def convert_to_cladogram(tree):
    """
    Convert tree to cladogram by setting all branch lengths to 1.0.
    This preserves topology but removes distance information.

    Args:
        tree: Phylo tree object

    Returns:
        Modified tree with equal branch lengths
    """
    # Set all branch lengths to 1.0
    for clade in tree.find_clades():
        if clade.branch_length is not None:
            clade.branch_length = 1.0
        else:
            clade.branch_length = 1.0

    return tree


def print_tree_info(tree, full_tree, query_samples=None, is_cladogram=False):
    """Print summary information about the tree."""
    leaves = tree.get_terminals()
    leaf_count = len(leaves)

    # Calculate tree heights (only meaningful for phylograms)
    if not is_cladogram:
        subtree_height = get_tree_height(tree)
        full_height = get_tree_height(full_tree)

    if query_samples:
        print(f"Clade containing: {', '.join(query_samples)}")
    else:
        print(f"Complete tree")

    print(f"Total leaves in view: {leaf_count}")

    if is_cladogram:
        print(f"Display mode: Cladogram (topology only, equal branch lengths)")
    else:
        print(f"Display mode: Phylogram (branch lengths represent evolutionary distance)")
        print(f"Tree height (max root-to-leaf distance): {subtree_height:.6f}")

        # If viewing a subtree, show comparison to full tree
        if query_samples and abs(subtree_height - full_height) > 0.0001:
            print(f"  (Full tree height: {full_height:.6f})")

    print(f"{'=' * 80}\n")


def draw_ascii_tree(tree):
    """
    Draw tree in ASCII format using Phylo's built-in draw_ascii.
    """
    # Create string buffer to capture output
    output = StringIO()

    # Draw tree
    Phylo.draw_ascii(tree, file=output, column_width=80)

    # Get the output
    tree_str = output.getvalue()
    output.close()

    return tree_str


def main():
    if len(sys.argv) < 2:
        print("Usage: python tree_view.py [--cladogram] <tree.newick> [sample1] [sample2] ...")
        print("\nOptions:")
        print("  --cladogram, -c    Display as cladogram (topology only, equal branch lengths)")
        print("                     Useful for visualizing structure in tight clades")
        print("\nExamples:")
        print("  # View entire tree as phylogram (with branch lengths)")
        print("  python tree_view.py tree.newick")
        print()
        print("  # View as cladogram (topology only)")
        print("  python tree_view.py --cladogram tree.newick")
        print()
        print("  # View clade containing specific samples")
        print("  python tree_view.py tree.newick 'Barcode-7-Scaffolds.fasta' 'Barcode-8-Scaffolds.fasta'")
        print()
        print("  # Cladogram of tight clade (best for closely related samples)")
        print("  python tree_view.py -c tree.newick 'Barcode-8-Scaffolds.fasta' 'Barcode-9-Scaffolds.fasta'")
        sys.exit(1)

    # Parse arguments
    args = sys.argv[1:]
    is_cladogram = False

    # Check for cladogram flag
    if args[0] in ['--cladogram', '-c']:
        is_cladogram = True
        args = args[1:]

    if len(args) < 1:
        print("ERROR: Tree file required")
        sys.exit(1)

    tree_file = args[0]
    query_samples = args[1:] if len(args) > 1 else None

    # Load and optionally filter tree
    tree, full_tree = get_ascii_tree(tree_file, query_samples)

    # Convert to cladogram if requested
    if is_cladogram:
        tree = convert_to_cladogram(tree)

    # Print info with tree height
    print_tree_info(tree, full_tree, query_samples, is_cladogram)

    # Draw ASCII tree
    tree_str = draw_ascii_tree(tree)
    print(tree_str)

    # If filtered, show what was excluded
    if query_samples:
        total_leaves = len(full_tree.get_terminals())
        shown_leaves = len(tree.get_terminals())
        excluded = total_leaves - shown_leaves

        print(f"\n{'=' * 80}")
        print(f"Showing {shown_leaves} of {total_leaves} total leaves ({excluded} excluded)")


if __name__ == "__main__":
    main()
