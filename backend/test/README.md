# WalkiCar Backend Tests

## Unit Tests
```bash
npm run test
```

## E2E Tests
```bash
npm run test:e2e
```

## Test Coverage
```bash
npm run test:cov
```

## Test Files Structure
- `src/**/*.spec.ts` - Unit tests
- `test/**/*.e2e-spec.ts` - E2E tests
- `test/jest-e2e.json` - E2E test configuration

## Test Database
Tests use a separate test database:
- `walkicar_test` - Test database
- Automatic cleanup after each test
- Isolated test data

## Mocking
- External services are mocked
- Database operations use test transactions
- API calls are intercepted for testing
