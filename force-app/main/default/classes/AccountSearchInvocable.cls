/**
 * Invocable Apex action: search Accounts by name.
 *
 * Callable from Flow Builder, and directly over the Actions API at
 * POST /services/data/vXX.X/actions/custom/apex/AccountSearchInvocable
 * which is how the "apex-server" MCP server reaches it.
 */
global with sharing class AccountSearchInvocable {
    global class Request {
        @InvocableVariable(label='Search Term' description='Full or partial account name' required=true)
        global String searchTerm;

        @InvocableVariable(label='Max Results' description='Maximum rows to return (1-200, default 10)')
        global Integer maxResults;
    }

    global class Result {
        @InvocableVariable(label='Success')
        global Boolean success;

        @InvocableVariable(label='Error Message')
        global String errorMessage;

        @InvocableVariable(label='Match Count')
        global Integer matchCount;

        @InvocableVariable(label='Matching Accounts')
        global List<Account> accounts;
    }

    @InvocableMethod(
        label='Search Accounts by Name'
        description='Returns Accounts whose Name contains the search term, with core CRM fields populated.'
        category='MCP Account Tools'
    )
    global static List<Result> search(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            try {
                res.accounts = AccountMcpSelector.searchByName(req.searchTerm, req.maxResults);
                res.matchCount = res.accounts.size();
                res.success = true;
            } catch (Exception e) {
                res.success = false;
                res.errorMessage = e.getMessage();
                res.matchCount = 0;
                res.accounts = new List<Account>();
            }
            results.add(res);
        }

        return results;
    }
}