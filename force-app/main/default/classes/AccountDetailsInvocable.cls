/**
 * Invocable Apex action: read one Account plus its related records.
 *
 * Callable from Flow Builder, and directly over the Actions API at
 * POST /services/data/vXX.X/actions/custom/apex/AccountDetailsInvocable
 * which is how the "apex-server" MCP server reaches it.
 *
 * Accepts either an accountId or an accountName; the Id wins when both are set.
 */
global with sharing class AccountDetailsInvocable {
    global class Request {
        @InvocableVariable(label='Account Id' description='15- or 18-character Account Id')
        global String accountId;

        @InvocableVariable(label='Account Name' description='Used when no Account Id is supplied')
        global String accountName;
    }

    global class Result {
        @InvocableVariable(label='Success')
        global Boolean success;

        @InvocableVariable(label='Error Message')
        global String errorMessage;

        @InvocableVariable(label='Account')
        global Account accountRecord;

        @InvocableVariable(label='Owner Name')
        global String ownerName;

        @InvocableVariable(label='Related Contacts')
        global List<Contact> contacts;

        @InvocableVariable(label='Related Opportunities')
        global List<Opportunity> opportunities;
    }

    @InvocableMethod(
        label='Get Account Details'
        description='Returns one Account with its related contacts and opportunities.'
        category='MCP Account Tools'
    )
    global static List<Result> getDetails(List<Request> requests) {
        // Resolve every requested account first, then load related records in
        // two bulk queries so the action stays governor-safe when called in bulk.
        List<Account> resolved = new List<Account>();
        List<String> failures = new List<String>();
        Set<Id> accountIds = new Set<Id>();

        for (Request req : requests) {
            try {
                Account found = String.isNotBlank(req.accountId)
                    ? AccountMcpSelector.findById(req.accountId)
                    : AccountMcpSelector.findByName(req.accountName);

                if (found == null) {
                    resolved.add(null);
                    failures.add(
                        String.isNotBlank(req.accountId)
                            ? 'No account found with Id ' + req.accountId
                            : 'No account found matching name "' + req.accountName + '"'
                    );
                } else {
                    resolved.add(found);
                    failures.add(null);
                    accountIds.add(found.Id);
                }
            } catch (Exception e) {
                resolved.add(null);
                failures.add(e.getMessage());
            }
        }

        Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();
        Map<Id, List<Opportunity>> oppsByAccount = new Map<Id, List<Opportunity>>();

        if (!accountIds.isEmpty()) {
            for (Contact c : AccountMcpSelector.contactsFor(accountIds)) {
                if (!contactsByAccount.containsKey(c.AccountId)) {
                    contactsByAccount.put(c.AccountId, new List<Contact>());
                }
                contactsByAccount.get(c.AccountId).add(c);
            }
            for (Opportunity o : AccountMcpSelector.opportunitiesFor(accountIds)) {
                if (!oppsByAccount.containsKey(o.AccountId)) {
                    oppsByAccount.put(o.AccountId, new List<Opportunity>());
                }
                oppsByAccount.get(o.AccountId).add(o);
            }
        }

        List<Result> results = new List<Result>();
        for (Integer i = 0; i < resolved.size(); i++) {
            Result res = new Result();
            Account record = resolved[i];

            if (record == null) {
                res.success = false;
                res.errorMessage = failures[i];
                res.contacts = new List<Contact>();
                res.opportunities = new List<Opportunity>();
            } else {
                res.success = true;
                res.accountRecord = record;
                res.ownerName = record.Owner != null ? record.Owner.Name : null;
                res.contacts = contactsByAccount.containsKey(record.Id)
                    ? contactsByAccount.get(record.Id)
                    : new List<Contact>();
                res.opportunities = oppsByAccount.containsKey(record.Id)
                    ? oppsByAccount.get(record.Id)
                    : new List<Opportunity>();
            }
            results.add(res);
        }

        return results;
    }
}