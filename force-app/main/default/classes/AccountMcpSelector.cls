/**
 * Shared query layer for the Account MCP tools.
 *
 * Both surfaces delegate here so the REST service and the invocable actions
 * always return the same fields and honour the same limits:
 *   - AccountMcpService        (@RestResource)
 *   - AccountSearchInvocable   (@InvocableMethod)
 *   - AccountDetailsInvocable  (@InvocableMethod)
 */
public with sharing class AccountMcpSelector {
    public static final Integer DEFAULT_LIMIT = 10;
    public static final Integer MAX_LIMIT = 200;
    public static final Integer RELATED_LIMIT = 25;

    public class InvalidInputException extends Exception {}

    public static List<Account> searchByName(String term, Integer requestedLimit) {
        if (String.isBlank(term)) {
            throw new InvalidInputException('A search term is required.');
        }
        Integer rowLimit = normalizeLimit(requestedLimit);
        String pattern = '%' + sanitizeForLike(term) + '%';

        return [
            SELECT Id, Name, Industry, Type, Rating, Website, Phone, AnnualRevenue,
                   BillingCity, BillingState, BillingCountry
            FROM Account
            WHERE Name LIKE :pattern
            WITH USER_MODE
            ORDER BY Name
            LIMIT :rowLimit
        ];
    }

    public static Account findById(String rawId) {
        if (String.isBlank(rawId)) {
            throw new InvalidInputException('An account Id is required.');
        }
        if (!(rawId instanceof Id)) {
            throw new InvalidInputException('"' + rawId + '" is not a valid Salesforce Id.');
        }
        Id accountId = (Id) rawId;
        List<Account> rows = [
            SELECT Id, Name, Industry, Type, Rating, Website, Phone, AnnualRevenue,
                   BillingCity, BillingState, BillingCountry, Description,
                   NumberOfEmployees, LastModifiedDate, Owner.Name
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    public static Account findByName(String term) {
        if (String.isBlank(term)) {
            throw new InvalidInputException('An account name is required.');
        }
        String pattern = '%' + sanitizeForLike(term) + '%';
        List<Account> rows = [
            SELECT Id, Name, Industry, Type, Rating, Website, Phone, AnnualRevenue,
                   BillingCity, BillingState, BillingCountry, Description,
                   NumberOfEmployees, LastModifiedDate, Owner.Name
            FROM Account
            WHERE Name LIKE :pattern
            WITH USER_MODE
            ORDER BY Name
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<Contact> contactsFor(Set<Id> accountIds) {
        return [
            SELECT Id, Name, Title, Email, Phone, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds
            WITH USER_MODE
            ORDER BY Name
            LIMIT :RELATED_LIMIT
        ];
    }

    public static List<Opportunity> opportunitiesFor(Set<Id> accountIds) {
        return [
            SELECT Id, Name, StageName, Amount, CloseDate, IsClosed, AccountId
            FROM Opportunity
            WHERE AccountId IN :accountIds
            WITH USER_MODE
            ORDER BY CloseDate DESC
            LIMIT :RELATED_LIMIT
        ];
    }

    public static Integer normalizeLimit(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_LIMIT;
        }
        return Math.min(requested, MAX_LIMIT);
    }

    public static Integer parseLimit(String raw) {
        if (String.isBlank(raw)) {
            return DEFAULT_LIMIT;
        }
        try {
            return normalizeLimit(Integer.valueOf(raw));
        } catch (Exception e) {
            return DEFAULT_LIMIT;
        }
    }

    /** Neutralise LIKE wildcards so a term such as "100%" matches literally. */
    public static String sanitizeForLike(String term) {
        return term.trim().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
    }
}