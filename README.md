# Hostel Mess Management System

## Project Overview

This project is a database system for managing a hostel mess. It handles daily meal planning, student attendance, leave tracking, ratings, food waste, and automatic meal replacement.

The system is built using Oracle SQL and PL/SQL.

## Main Features

* Weekly menu generation
* Student meal scan tracking
* Leave management system
* Meal rating system
* Waste tracking for each meal
* Analytics calculation for performance
* Automatic meal swapping based on poor performance

## Database Components

The system includes the following tables:

* USERS
* MEALS
* MENU
* SCANS
* LEAVE_APPLICATION
* RATINGS
* WASTE_LOG
* MEAL_ANALYTICS
* SWAP_HISTORY

## Business Logic

The system uses:

* Triggers to enforce rules
* Procedures to calculate analytics and perform swaps
* Functions for reusable calculations

Examples:

* Students cannot scan meals during approved leave
* Ratings are only allowed if a meal was consumed
* Scan timing is validated based on meal type

## Simulation

The script includes an 8 week simulation that:

* Generates menu data
* Creates random student attendance
* Applies leave scenarios
* Generates ratings and waste
* Updates analytics
* Performs weekly meal swaps

## Queries

The project includes analytical queries such as:

* Top rated meals
* Most wasted meals
* Most swapped meals
* Attendance analysis
* Swap effectiveness
* Weekly performance

## How to Run

1. Open the SQL file in Oracle SQL Developer or SQL Plus
2. Run the full script
3. Wait for simulation to complete
4. Run queries to view results

## Technologies Used

* Oracle SQL
* PL/SQL

## Notes

* The system uses sequences for ID generation
* Constraints ensure data integrity
* Transaction control is used inside the simulation

## Authors

* Himantveer Kaur (1024170271)
* Muskan Kohli (1024170453)
* Ansh Bindal (1024170273)
