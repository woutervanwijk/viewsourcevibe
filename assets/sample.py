# Sample Python file for testing syntax highlighting
# This demonstrates various Python language features

import os
import sys
from datetime import datetime
import json
from typing import List, Dict, Optional, Union

# Constants
APP_NAME = "HTML Viewer"
VERSION = "1.0.0"
MAX_CONNECTIONS = 100

# Classes
class User:
    """A class representing a user."""
    
    def __init__(self, name: str, email: str, age: int = None):
        self.name = name
        self.email = email
        self.age = age
        self.created_at = datetime.now()
    
    def greet(self) -> str:
        """Return a greeting message."""
        return f"Hello, {self.name}!"
    
    def get_info(self) -> Dict[str, Union[str, int, datetime]]:
        """Return user information as a dictionary."""
        return {
            'name': self.name,
            'email': self.email,
            'age': self.age,
            'created_at': self.created_at.isoformat()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Union[str, int]]) -> 'User':
        """Create a User instance from a dictionary."""
        return cls(
            name=data['name'],
            email=data['email'],
            age=data.get('age')
        )

# Functions
def calculate_factorial(n: int) -> int:
    """Calculate the factorial of a number."""
    if n == 0:
        return 1
    return n * calculate_factorial(n - 1)

def read_file(filename: str) -> Optional[str]:
    """Read a file and return its content."""
    try:
        with open(filename, 'r', encoding='utf-8') as file:
            return file.read()
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        return None
    except Exception as e:
        print(f"Error reading file: {e}")
        return None

def process_users(users: List[User]) -> List[Dict[str, Union[str, int]]]:
    """Process a list of users and return their information."""
    return [user.get_info() for user in users]

# Async/Await example
async def fetch_data(url: str) -> Optional[Dict]:
    """Asynchronously fetch data from a URL."""
    # In a real implementation, this would use aiohttp or similar
    print(f"Fetching data from {url}...")
    await asyncio.sleep(1)  # Simulate network delay
    return {'status': 'success', 'data': 'sample data'}

# Main function
def main():
    """Main entry point of the application."""
    print(f"Welcome to {APP_NAME} v{VERSION}")
    
    # Create some users
    users = [
        User(name="Alice", email="alice@example.com", age=30),
        User(name="Bob", email="bob@example.com", age=25),
        User(name="Charlie", email="charlie@example.com")
    ]
    
    # Process users
    user_data = process_users(users)
    print(f"Processed {len(user_data)} users")
    
    # Demonstrate list comprehension
    names = [user.name for user in users]
    print(f"User names: {', '.join(names)}")
    
    # Demonstrate dictionary comprehension
    name_email_map = {user.name: user.email for user in users}
    print(f"Name-Email mapping: {name_email_map}")
    
    # Exception handling example
    try:
        result = calculate_factorial(5)
        print(f"Factorial of 5: {result}")
        
        # This will raise an exception
        calculate_factorial(-1)
    except RecursionError:
        print("Error: Factorial is not defined for negative numbers.")
    except Exception as e:
        print(f"An error occurred: {e}")
    
    # File operations
    content = read_file("config.json")
    if content:
        try:
            config = json.loads(content)
            print(f"Loaded config: {config}")
        except json.JSONDecodeError:
            print("Error: Invalid JSON in config file.")

# Decorators
def log_execution_time(func):
    """Decorator to log function execution time."""
    def wrapper(*args, **kwargs):
        start_time = datetime.now()
        result = func(*args, **kwargs)
        end_time = datetime.now()
        execution_time = end_time - start_time
        print(f"Function '{func.__name__}' executed in {execution_time.total_seconds():.4f} seconds")
        return result
    return wrapper

@log_execution_time
def complex_calculation():
    """A function that performs complex calculations."""
    total = 0
    for i in range(1000000):
        total += i
    return total

# Generators
def fibonacci_sequence(n: int):
    """Generate Fibonacci sequence up to n terms."""
    a, b = 0, 1
    for _ in range(n):
        yield a
        a, b = b, a + b

# Context managers
class Timer:
    """Context manager for timing code execution."""
    
    def __enter__(self):
        self.start = datetime.now()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.end = datetime.now()
        self.elapsed = self.end - self.start
        print(f"Elapsed time: {self.elapsed.total_seconds():.4f} seconds")

if __name__ == "__main__":
    main()
    
    # Demonstrate generator
    print("First 10 Fibonacci numbers:")
    for i, num in enumerate(fibonacci_sequence(10)):
        print(f"  {i+1}: {num}")
    
    # Demonstrate context manager
    with Timer():
        result = complex_calculation()
        print(f"Complex calculation result: {result}")