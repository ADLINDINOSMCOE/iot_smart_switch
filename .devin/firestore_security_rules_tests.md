# Firestore Security Rules Emulator Tests

This document describes how to test Firestore security rules using the Firebase emulators.

## Setup

### Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Start Emulators
```bash
firebase emulators:start
```

### Run Security Rule Tests
```bash
firebase emulators:exec --only firestore "npm test"
```

## Test Cases

### 1. Unauthenticated Access Tests

**Test: Deny unauthenticated access to switches collection**
```javascript
const assert = require('assert');
const { Firestore } = require('@google-cloud/firestore');

const db = new Firestore({
  projectId: 'demo-test-project',
  keyFilename: path.join(__dirname, 'service-account.json'),
});

// Test without authentication
try {
  await db.collection('switches').get();
  assert.fail('Should have thrown permission denied error');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

### 2. Authentication Tests

**Test: Allow authenticated user to read their own devices**
```javascript
const admin = require('firebase-admin');
const auth = admin.auth();

// Create test user
const user = await auth.createUser({
  email: 'test@example.com',
  password: 'password123',
});

// Test reading own devices
const db = admin.firestore();
const switches = await db.collection('switches')
  .where('ownerId', '==', user.uid)
  .get();

assert(!switches.empty, 'Should be able to read own devices');
```

### 3. Device Ownership Tests

**Test: Owner can read, write, and delete their device**
```javascript
const testData = {
  deviceId: 'test_device_1',
  name: 'Test Switch',
  ownerId: user.uid,
  isOn: false,
  online: false,
};

// Create device
const docRef = await db.collection('switches').add(testData);

// Owner should be able to read
const doc = await docRef.get();
assert(doc.exists, 'Owner should be able to read');

// Owner should be able to update
await docRef.update({ name: 'Updated Name' });

// Owner should be able to delete
await docRef.delete();
```

**Test: Non-owner cannot modify ownership fields**
```javascript
const deviceData = {
  deviceId: 'test_device_2',
  name: 'Test Switch',
  ownerId: user.uid,
  isOn: false,
  online: false,
};

const docRef = await db.collection('switches').add(deviceData);

// Create another user
const otherUser = await auth.createUser({
  email: 'other@example.com',
  password: 'password123',
});

// Try to update as other user using client SDK (not admin)
// This should fail
try {
  await db.collection('switches').doc(docRef.id).update({
    ownerId: otherUser.uid
  });
  assert.fail('Should not allow ownership transfer');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

### 4. Sharing Tests

**Test: Owner can share device with editor**
```javascript
const deviceData = {
  deviceId: 'test_device_3',
  name: 'Test Switch',
  ownerId: user.uid,
  isOn: false,
  online: false,
  sharedWith: { [otherUser.uid]: 'editor' },
  sharedWithUids: [otherUser.uid],
};

const docRef = await db.collection('switches').add(deviceData);

// Editor should be able to read
const doc = await docRef.get();
assert(doc.exists, 'Editor should be able to read');

// Editor should be able to control (update isOn)
await docRef.update({ isOn: true });
```

**Test: Editor cannot modify ownership or metadata**
```javascript
try {
  await docRef.update({
    name: 'Hacked Name',
    ownerId: otherUser.uid
  });
  assert.fail('Editor should not modify ownership/metadata');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

**Test: Viewer can only read**
```javascript
const deviceData = {
  deviceId: 'test_device_4',
  name: 'Test Switch',
  ownerId: user.uid,
  isOn: false,
  online: false,
  sharedWith: { [otherUser.uid]: 'viewer' },
  sharedWithUids: [otherUser.uid],
};

const docRef = await db.collection('switches').add(deviceData);

// Viewer should be able to read
const doc = await docRef.get();
assert(doc.exists, 'Viewer should be able to read');

// Viewer should NOT be able to write
try {
  await docRef.update({ isOn: true });
  assert.fail('Viewer should not be able to write');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

### 5. Schedule Validation Tests

**Test: Invalid schedule should be rejected**
```javascript
const invalidSchedule = {
  hour: 25, // Invalid: must be 0-23
  minute: 30,
  enabled: true,
  days: [1, 2, 3],
  action: 'TURN_ON',
  createdBy: user.uid,
  deviceId: 'test_device_1',
};

try {
  await db.collection('switches')
    .doc('test_device_1')
    .collection('schedules')
    .add(invalidSchedule);
  assert.fail('Invalid schedule should be rejected');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

**Test: Valid schedule should be accepted**
```javascript
const validSchedule = {
  hour: 10,
  minute: 30,
  enabled: true,
  days: [1, 2, 3, 4, 5],
  action: 'TURN_ON',
  createdBy: user.uid,
  deviceId: 'test_device_1',
};

const docRef = await db.collection('switches')
  .doc('test_device_1')
  .collection('schedules')
  .add(validSchedule);

assert(docRef.id, 'Valid schedule should be accepted');
```

### 6. Command Validation Tests

**Test: Invalid command action should be rejected**
```javascript
const invalidCommand = {
  action: 'INVALID_ACTION',
  targetState: true,
  requestedBy: user.uid,
  deviceId: 'test_device_1',
  status: 'PENDING',
};

try {
  await db.collection('switches')
    .doc('test_device_1')
    .collection('commands')
    .add(invalidCommand);
  assert.fail('Invalid command should be rejected');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

**Test: Valid command should be accepted**
```javascript
const validCommand = {
  action: 'TURN_ON',
  targetState: true,
  requestedBy: user.uid,
  deviceId: 'test_device_1',
  status: 'EXECUTED',
};

const docRef = await db.collection('switches')
  .doc('test_device_1')
  .collection('commands')
  .add(validCommand);

assert(docRef.id, 'Valid command should be accepted');
```

### 7. Timer History Validation Tests

**Test: Invalid timer action should be rejected**
```javascript
const invalidTimer = {
  action: 'INVALID',
  status: 'completed',
  startedBy: user.uid,
  deviceId: 'test_device_1',
  duration: 3600,
};

try {
  await db.collection('switches')
    .doc('test_device_1')
    .collection('timerHistory')
    .add(invalidTimer);
  assert.fail('Invalid timer should be rejected');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

### 8. Users Collection Privacy Tests

**Test: Users should not be broadly readable**
```javascript
// Try to read all users (should fail)
try {
  await db.collection('users').get();
  assert.fail('Should not allow broad users collection read');
} catch (error) {
  assert(error.code === 7, 'Expected permission denied');
}
```

**Test: User can read their own profile**
```javascript
const userData = {
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
};

await db.collection('users').doc(user.uid).set(userData);

// User should be able to read their own profile
const doc = await db.collection('users').doc(user.uid).get();
assert(doc.exists, 'User should read own profile');
```

## Running the Tests

### Automatic Test Script
Create a test script `test-firestore-rules.sh`:

```bash
#!/bin/bash

echo "Starting Firebase emulators..."
firebase emulators:start --only firestore &
EMULATOR_PID=$!

echo "Waiting for emulators to start..."
sleep 10

echo "Running security rule tests..."
firebase emulators:exec --only firestore "node test-firestore-rules.js"

echo "Stopping emulators..."
kill $EMULATOR_PID
```

### Manual Testing
```bash
# Start emulators
firebase emulators:start

# In another terminal, run tests
firebase emulators:exec --only firestore "npm test"
```

## Expected Results

All tests should pass with the current security rules configuration. If any test fails, review the corresponding rule in `firestore.rules`.

## Continuous Integration

Add to CI/CD pipeline:

```yaml
# .github/workflows/test-security-rules.yml
name: Test Firestore Security Rules

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '20'
      - run: npm install
      - run: firebase emulators:exec --only firestore "npm test"
```

## Troubleshooting

### Common Issues

1. **Emulator not starting**: Ensure Firebase CLI is installed and updated
2. **Permission errors**: Check that service account has proper permissions
3. **Test failures**: Review security rules for the specific collection being tested

### Debug Mode

Run emulators with debug logging:
```bash
firebase emulators:start --only firestore --debug
```

## Additional Resources

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Security Rules Testing](https://firebase.google.com/docs/rules/unit-tests)