/**
 * Apex REST service backing the "apex-server" MCP server.
 *
 * Endpoints (relative to /services/apexrest):
 *   GET /mcp/accounts/search?name=<term>&max=<n>
 *   GET /mcp/accounts/details?id=<accountId>
 *   GET /mcp/accounts/details?name=<exact or partial name>
 */
@RestResource(urlMapping='/mcp/accounts/*')
global with sharing class AccountMcpService {
    global class AccountSummary {
        global String id;
        global String name;
        global String industry;
        global String accountType;
        global String rating;
        global String website;
        global String phone;
        global Decimal annualRevenue;
        global String billingCity;
        global String billingState;
        global String billingCountry;
    }

    global class ContactSummary {
        global String id;
        global String name;
        global String title;
        global String email;
        global String phone;
    }

    global class OpportunitySummary {
        global String id;
        global String name;
        global String stageName;
        global Decimal amount;
        global Date closeDate;
        global Boolean isClosed;
    }

    global class AccountDetail {
        global AccountSummary account;
        global String description;
        global String ownerName;
        global Integer numberOfEmployees;
        global Datetime lastModifiedDate;
        global List<ContactSummary> contacts;
        global List<OpportunitySummary> opportunities;
    }

    global class ApiResponse {
        global Boolean success;
        global String error;
        global String searchTerm;
        global Integer count;
        global List<AccountSummary> accounts;
        global AccountDetail detail;
    }

    @HttpGet
    global static ApiResponse doGet() {
        RestRequest req = RestContext.request;
        String action = resolveAction(req.requestURI);

        try {
            if (action == 'search') {
                return search(param(req, 'name'), param(req, 'max'));
            } else if (action == 'details') {
                return details(param(req, 'id'), param(req, 'name'));
            }
            return fail('Unknown action "' + action + '". Use /mcp/accounts/search or /mcp/accounts/details.');
        } catch (AccountMcpSelector.InvalidInputException e) {
            RestContext.response.statusCode = 400;
            return fail(e.getMessage());
        } catch (McpServiceException e) {
            return fail(e.getMessage());
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            return fail(e.getTypeName() + ': ' + e.getMessage());
        }
    }

    private static ApiResponse search(String nameTerm, String maxRaw) {
        if (String.isBlank(nameTerm)) {
            RestContext.response.statusCode = 400;
            return fail('Query parameter "name" is required.');
        }

        List<Account> rows = AccountMcpSelector.searchByName(nameTerm, AccountMcpSelector.parseLimit(maxRaw));

        ApiResponse res = new ApiResponse();
        res.success = true;
        res.searchTerm = nameTerm;
        res.accounts = new List<AccountSummary>();
        for (Account a : rows) {
            res.accounts.add(toSummary(a));
        }
        res.count = res.accounts.size();
        return res;
    }

    private static ApiResponse details(String accountId, String nameTerm) {
        Account record = String.isNotBlank(accountId) ? findById(accountId) : findByName(nameTerm);

        if (record == null) {
            RestContext.response.statusCode = 404;
            return fail(
                String.isNotBlank(accountId)
                    ? 'No account found with Id ' + accountId
                    : 'No account found matching name "' + nameTerm + '"'
            );
        }

        AccountDetail detail = new AccountDetail();
        detail.account = toSummary(record);
        detail.description = record.Description;
        detail.ownerName = record.Owner.Name;
        detail.numberOfEmployees = record.NumberOfEmployees;
        detail.lastModifiedDate = record.LastModifiedDate;
        detail.contacts = new List<ContactSummary>();
        detail.opportunities = new List<OpportunitySummary>();

        Set<Id> ids = new Set<Id>{ record.Id };

        for (Contact c : AccountMcpSelector.contactsFor(ids)) {
            ContactSummary cs = new ContactSummary();
            cs.id = c.Id;
            cs.name = c.Name;
            cs.title = c.Title;
            cs.email = c.Email;
            cs.phone = c.Phone;
            detail.contacts.add(cs);
        }

        for (Opportunity o : AccountMcpSelector.opportunitiesFor(ids)) {
            OpportunitySummary os = new OpportunitySummary();
            os.id = o.Id;
            os.name = o.Name;
            os.stageName = o.StageName;
            os.amount = o.Amount;
            os.closeDate = o.CloseDate;
            os.isClosed = o.IsClosed;
            detail.opportunities.add(os);
        }

        ApiResponse res = new ApiResponse();
        res.success = true;
        res.detail = detail;
        res.count = 1;
        return res;
    }

    private static Account findById(String accountId) {
        return AccountMcpSelector.findById(accountId);
    }

    private static Account findByName(String nameTerm) {
        return AccountMcpSelector.findByName(nameTerm);
    }

    private static AccountSummary toSummary(Account a) {
        AccountSummary s = new AccountSummary();
        s.id = a.Id;
        s.name = a.Name;
        s.industry = a.Industry;
        s.accountType = a.Type;
        s.rating = a.Rating;
        s.website = a.Website;
        s.phone = a.Phone;
        s.annualRevenue = a.AnnualRevenue;
        s.billingCity = a.BillingCity;
        s.billingState = a.BillingState;
        s.billingCountry = a.BillingCountry;
        return s;
    }

    /** Last non-empty URI segment: "/mcp/accounts/search" -> "search". */
    private static String resolveAction(String uri) {
        if (String.isBlank(uri)) {
            return '';
        }
        List<String> parts = uri.split('/');
        for (Integer i = parts.size() - 1; i >= 0; i--) {
            if (String.isNotBlank(parts[i])) {
                return parts[i].toLowerCase();
            }
        }
        return '';
    }

    private static String param(RestRequest req, String key) {
        return req.params.containsKey(key) ? req.params.get(key) : null;
    }

    private static ApiResponse fail(String message) {
        ApiResponse res = new ApiResponse();
        res.success = false;
        res.error = message;
        res.count = 0;
        return res;
    }

    global class McpServiceException extends Exception {}
}