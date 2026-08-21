const databaseUrl = process.env.FOCUS_FLOW_TEST_DATABASE_URL;

if (!databaseUrl) {
  throw new Error('FOCUS_FLOW_TEST_DATABASE_URL is required for integration tests');
}

if (databaseUrl.includes('密码') || databaseUrl.includes('主机')) {
  throw new Error('Replace the example password and host with a real dedicated PostgreSQL test database connection string');
}

const databaseName = new URL(databaseUrl).pathname.replace(/^\//, '');
if (!/(^|[_-])test([_-]|$)/i.test(databaseName)) {
  throw new Error('FOCUS_FLOW_TEST_DATABASE_URL must target a dedicated database whose name contains "test"');
}
