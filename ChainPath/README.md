# ChainPath Marketplace Verification System

A comprehensive blockchain-based supply chain tracking and verification system built on the Stacks blockchain using Clarity smart contracts.

## Overview

ChainPath provides end-to-end traceability for products moving through supply chains, enabling manufacturers, distributors, inspectors, and consumers to verify product authenticity, track locations, monitor conditions, and manage certifications throughout the product lifecycle.

## Features

### Core Functionality
- **Product Registration**: Register new items with detailed metadata
- **Supply Chain Tracking**: Track items through checkpoints and transfers
- **Environmental Monitoring**: Record temperature and humidity data
- **Transfer Management**: Initiate, accept, and reject custody transfers
- **Authorization System**: Manage inspector permissions
- **Certification Management**: Add and revoke product certifications
- **Product Recalls**: Handle product recall scenarios
- **Verification**: Verify product authenticity and status

### Security Features
- Comprehensive input validation for all parameters
- Authorization checks for sensitive operations
- Protection against recalled item modifications
- Secure transfer workflow with acceptance/rejection

## Data Structures

### Items
Each registered item contains:
- Basic info: title, details, creator, lot number, category
- Location tracking: current location, keeper, destination
- Status: produced, shipping, delivered, sold, recalled
- Counters: checkpoint and transfer event counts
- Metadata: optional additional information
- Timestamps: creation and arrival times

### Events
Combined tracking system for checkpoints and transfers:
- Location and timestamp data
- Environmental conditions (temperature, humidity)
- Event types: checkpoint, transfer-start, transfer-complete
- Transfer participants (from/to keepers)
- Status tracking: active, pending, completed, rejected
- Cryptographic hashes for integrity

### Certifications
Product certifications with:
- Certification authority and standards
- Validity periods and expiration
- Document hashes and URLs
- Revocation capabilities

## Public Functions

### Product Management

#### `register-item`
Register a new item in the system.
```clarity
(register-item title details lot category location metadata)
```
- **Parameters**: Product details and initial location
- **Returns**: Unique item ID
- **Access**: Any user can register items

#### `recall-item`
Recall a product with specified reason.
```clarity
(recall-item item-id reason)
```
- **Parameters**: Item ID and recall reason
- **Returns**: Success confirmation
- **Access**: Item creator only

### Tracking and Events

#### `add-event`
Add checkpoint or initiate transfer.
```clarity
(add-event item-id location event-type to-keeper temp humidity notes)
```
- **Parameters**: Item ID, location, event type, optional transfer recipient, environmental data, notes
- **Returns**: Event ID
- **Access**: Item keeper or authorized inspectors

#### `accept-transfer`
Accept a pending transfer.
```clarity
(accept-transfer item-id event-id)
```
- **Parameters**: Item and event IDs
- **Returns**: Success confirmation
- **Access**: Designated transfer recipient only

#### `reject-transfer`
Reject a pending transfer.
```clarity
(reject-transfer item-id event-id)
```
- **Parameters**: Item and event IDs
- **Returns**: Success confirmation
- **Access**: Designated transfer recipient only

### Authorization Management

#### `authorize-inspector`
Grant inspector permissions to another user.
```clarity
(authorize-inspector inspector name role)
```
- **Parameters**: Inspector principal, name, and role
- **Returns**: Success confirmation
- **Access**: Organization owners

#### `revoke-inspector`
Revoke inspector permissions.
```clarity
(revoke-inspector inspector)
```
- **Parameters**: Inspector principal
- **Returns**: Success confirmation
- **Access**: Organization owners

### Certification Management

#### `add-cert`
Add certification to an item.
```clarity
(add-cert item-id standard expires hash url)
```
- **Parameters**: Item ID, certification standard, expiration, document hash, optional URL
- **Returns**: Success confirmation
- **Access**: Item creator or authorized users

#### `revoke-cert`
Revoke an existing certification.
```clarity
(revoke-cert item-id standard)
```
- **Parameters**: Item ID and certification standard
- **Returns**: Success confirmation
- **Access**: Certification authority only

### Delivery Management

#### `set-delivery`
Set delivery destination and expected arrival.
```clarity
(set-delivery item-id destination arrival)
```
- **Parameters**: Item ID, destination, arrival block height
- **Returns**: Success confirmation
- **Access**: Item keeper or authorized inspectors

## Read-Only Functions

### `get-item`
Retrieve complete item information.
```clarity
(get-item item-id)
```

### `get-event`
Retrieve specific event details.
```clarity
(get-event item-id event-id)
```

### `get-cert`
Retrieve certification information.
```clarity
(get-cert item-id standard)
```

### `is-cert-valid`
Check if a certification is currently valid.
```clarity
(is-cert-valid item-id standard)
```

### `verify-item`
Quick verification of item authenticity and status.
```clarity
(verify-item item-id)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-INVALID-INPUT | Invalid input parameters |
| 101 | ERR-ITEM-NOT-FOUND | Item does not exist |
| 102 | ERR-NOT-AUTHORIZED | Insufficient permissions |
| 103 | ERR-ITEM-RECALLED | Operation not allowed on recalled items |
| 104 | ERR-EVENT-NOT-FOUND | Event does not exist |
| 105 | ERR-NOT-RECIPIENT | Not the designated transfer recipient |
| 106 | ERR-NOT-PENDING | Transfer is not in pending status |
| 107 | ERR-INVALID-EXPIRY | Invalid expiration date |
| 108 | ERR-NOT-AUTHORITY | Not the certification authority |
| 109 | ERR-ONLY-CREATOR | Operation restricted to item creator |

## Validation Rules

### String Validation
- UTF-8 strings: Non-empty, within specified length limits
- ASCII strings: Non-empty, within specified length limits
- Optional strings: Empty or within limits when present

### Numerical Validation
- Item IDs: Must exist in the system
- Temperature: Range -100°C to 100°C
- Humidity: 0% to 100%
- Block heights: Must be future blocks for expiration/arrival

### Business Logic Validation
- Authorization checks for all sensitive operations
- Recalled items cannot be modified (except by creator)
- Transfer recipients must match designated keepers
- Certifications must have future expiration dates

## Usage Examples

### Basic Supply Chain Flow

1. **Register Product**
```clarity
(register-item "Organic Apples" "Premium organic apples from Farm A" "LOT001" "food" "Farm A, California" (some "Pesticide-free"))
```

2. **Add Checkpoint**
```clarity
(add-event u0 "Warehouse B" "checkpoint" none (some -2) (some u85) (some "Quality check passed"))
```

3. **Initiate Transfer**
```clarity
(add-event u0 "Distribution Center" "transfer-start" (some 'SP1234...DISTRIBUTOR) none none (some "Shipping to distributor"))
```

4. **Accept Transfer**
```clarity
(accept-transfer u0 u1)  ;; Called by distributor
```

5. **Add Certification**
```clarity
(add-cert u0 "ORGANIC-USDA" u1050000 0x1234abcd... (some "https://certs.usda.gov/doc123"))
```

### Inspector Authorization

```clarity
;; Authorize inspector
(authorize-inspector 'SP5678...INSPECTOR "John Smith" "Quality Control")

;; Inspector can now add events for items owned by the authorizing organization
```

### Product Recall

```clarity
;; Recall product (creator only)
(recall-item u0 "Contamination detected in lot LOT001")
```

## Best Practices

### For Manufacturers
- Register items immediately upon production
- Add detailed metadata and lot information
- Authorize trusted inspectors for quality control
- Implement recall procedures for safety

### For Distributors
- Accept transfers promptly to maintain chain of custody
- Add checkpoints at key distribution points
- Monitor environmental conditions for sensitive products
- Verify certifications before accepting items

### For Inspectors
- Record detailed notes during inspections
- Include environmental data when relevant
- Maintain accurate location information
- Report issues immediately through the system

### For Developers
- Always validate inputs before contract calls
- Handle error codes appropriately in applications
- Implement proper authorization checks
- Monitor gas costs for batch operations

## Integration Guidelines

### Frontend Applications
- Use read-only functions for displaying product information
- Implement proper error handling for all contract calls
- Cache frequently accessed data to reduce blockchain queries
- Provide clear user feedback for pending operations

### API Development
- Implement rate limiting for contract interactions
- Use event indexing for efficient data retrieval
- Provide webhook notifications for status changes
- Maintain off-chain databases for search functionality

### Mobile Applications
- Implement QR code scanning for quick product lookup
- Provide offline mode with sync capabilities
- Use push notifications for transfer requests
- Implement location-based features for nearby items

## Security Considerations

- All inputs are validated to prevent malicious data
- Authorization checks prevent unauthorized modifications
- Cryptographic hashes ensure data integrity
- Transfer workflow prevents unauthorized custody changes
- Recall functionality provides emergency response capability

## Deployment

This contract is designed for deployment on the Stacks blockchain. Ensure proper testing on testnet before mainnet deployment.

### Prerequisites
- Stacks blockchain node access
- Clarity CLI for testing
- Sufficient STX tokens for deployment

### Testing
Run comprehensive tests covering:
- Input validation edge cases
- Authorization boundary conditions
- Transfer workflow scenarios
- Certification lifecycle management
- Recall procedures

## Contributing

When contributing to this project:
1. Maintain comprehensive input validation
2. Add appropriate error handling
3. Update documentation for new features
4. Include test cases for all modifications
5. Follow existing code style and patterns
