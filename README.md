# DBT Data Transformation Project

## Overview
This project implements a centralized data transformation methodology using DBT (Data Build Tool) to standardize the creation and management of data products across the organization.

### Current Challenges
- Decentralized data transformation processes
- Heavy reliance on Tableau for ETL operations
- Limited reusability of data sources
- Difficult coordination of changes across multiple data sources
- Lack of standardized documentation and traceability
- Diluted data ownership
- Inconsistent naming conventions and criteria

### Project Goals
- Implement standardized data transformations (simple and complex)
- Establish clear domain ownership
- Improve traceability through standardized documentation
- Enable data product reusability
- Implement quality monitoring and alerts

## Project Structure: **Nubeproduct**

### Models Directory
The project follows a layered approach to data transformation:

#### 1. Staging Layer (`models/staging/`)
- Purpose: Initial and reusable transformations of source data
- Transformations:
  - Renaming
  - Data type casting
  - Basic computations
  - Categorization
- Output: Tables 

#### 2. Intermediate Layer (`models/intermediate/`)
- Purpose: Complex transformations and business logic
- Organization: Subdirectories based on business domains
- Transformations:
  - Aggregations
  - Joins
  - Pivoting
  - Complex computations
- Output: Ephemeral models

#### 3. Marts Layer (`models/marts/`)
- Purpose: Final presentation layer combining modular pieces
- Output: Business-ready data models

### Additional Components

#### Seeds Directory (`seeds/`)
- Purpose: Store lookup tables and static data
- Use Case: Reference data not available in source systems

#### Configuration Files
1. `dbt_project.yml`
   - Directory configurations
   - Model run settings
   - Default materializations
   - Schema definitions

2. Model YAML Files
   - One `_[directory]_models.yml` per directory
   - For staging: Additional `_[directory]_sources.yml`

## Setup Instructions
1. Ensure Python 3.7+ is installed
2. Create and activate virtual environment:
   ```bash
   virtualenv -p python3.10 env
   source env/bin/activate
   ```
3. Install dependencies:
   ```bash
   python -m pip install dbt-core dbt-databricks
   ```
4. Enter project:
   ```bash
   cd nubeproduct/
   ```
5. Configure connection profiles in `~/.dbt/profiles.yml`

## Best Practices
- Use consistent naming conventions
- Document all models and transformations
- Leverage cascading configurations in `dbt_project.yml`
- Maintain clear model dependencies
- Follow the established layer structure for new developments