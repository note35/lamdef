"""
Test file for multiline lambda extraction plugin.
This file contains lamdef examples that can be tested with the Vim plugin.
"""

from datetime import datetime, timedelta


class User:
    """User class for testing lambda extraction."""
    
    def __init__(self, name, is_inactive=False, last_seen=None, base_priority=0):
        self.name = name
        self.is_inactive = is_inactive
        self.last_seen = last_seen or datetime.now()
        self.base_priority = base_priority
    
    def calculate_priority(self):
        """Calculate user priority based on various factors."""
        if self.is_inactive:
            return -1
        return self.base_priority + len(self.name)
    
    def __repr__(self):
        return f"User(name='{self.name}', inactive={self.is_inactive}, priority={self.calculate_priority()})"


# Create test users
users = [
    User("Alice", is_inactive=False, base_priority=10),
    User("Bob", is_inactive=True, last_seen=datetime.now() - timedelta(days=30)),
    User("Charlie", is_inactive=False, base_priority=5),
    User("Diana", is_inactive=True, last_seen=datetime.now() - timedelta(days=60)),
    User("Eve", is_inactive=False, base_priority=8),
]


# MODULE LEVEL TEST CASE
# Place cursor on the line below with lamdef and press Ctrl+E
# Sort: by priority descending
sorted_users = sorted(users, key=lamdef(user):
    priority = user.calculate_priority()
    return -priority
)


def test_module_level_sorting():
    """Test that module-level sorted_users is correct."""
    print("\n=== Module Level Test ===")
    print("Sorted users (by priority desc):")
    for user in sorted_users:
        print(f"  {user}")


def process_users_function_level(user_list):
    """
    FUNCTION LEVEL TEST CASE
    Place cursor on the line below with lamdef and press Ctrl+E
    """
    # Sort: by name length ascending
    ranked_users = sorted(user_list, key=lamdef(user):
        name_length = len(user.name)
        return name_length
    )
    
    return ranked_users


def test_function_level_sorting():
    """Test that function-level sorting works correctly."""
    print("\n=== Function Level Test ===")
    result = process_users_function_level(users)
    print("Sorted users (by name length asc):")
    for user in result:
        print(f"  {user}")


def test_with_nested_indentation():
    """
    Test with deeper nesting level.
    Place cursor on the lamdef line and press Ctrl+E
    """
    if True:
        # Sort: by name alphabetically
        sorted_by_name = sorted(users, key=lamdef(u):
            return u.name
        )
        
        print("\n=== Nested Indentation Test ===")
        print("Sorted users (by name alphabetically):")
        for user in sorted_by_name:
            print(f"  {user}")


def test_direct_assignment():
    """
    Test direct function assignment.
    Place cursor on the lamdef line and press Ctrl+E
    """
    # Direct assignment: function name same as variable
    add_one = lamdef(x):
        result = x + 1
        return result
    
    print("\n=== Direct Assignment Test ===")
    print(f"add_one(5) = {add_one(5)}")


def test_filter_usage():
    """
    Test with filter() function.
    Place cursor on the lamdef line and press Ctrl+E
    """
    numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    # Filter: keep only even numbers
    evens = list(filter(lamdef(n):
        return n % 2 == 0
    , numbers))
    
    print("\n=== Filter Usage Test ===")
    print(f"Original: {numbers}")
    print(f"Evens: {evens}")


if __name__ == "__main__":
    print("Testing multiline lambda extraction plugin...")
    print("=" * 60)
    
    print("\nOriginal users:")
    for user in users:
        print(f"  {user}")
    
    # Run tests
    test_module_level_sorting()
    test_function_level_sorting()
    test_with_nested_indentation()
    test_direct_assignment()
    test_filter_usage()
    
    print("\n" + "=" * 60)
    print("All tests completed!")
    print("\nTo test the Vim plugin:")
    print("1. Open this file in Vim")
    print("2. Navigate to any line with 'lamdef'")
    print("3. Press Ctrl+E")
    print("4. Run: python test_lamdef.py")
    print("5. Visually verify the sorting results match expectations")
