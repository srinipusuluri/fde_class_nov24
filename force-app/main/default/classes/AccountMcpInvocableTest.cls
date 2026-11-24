@IsTest
private class AccountMcpInvocableTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Invocable Alpha Corp', Industry = 'Technology', Rating = 'Hot', AnnualRevenue = 750000),
            new Account(Name = 'Invocable Beta Corp', Industry = 'Retail', Rating = 'Cold'),
            new Account(Name = 'Outside The Search', Industry = 'Energy')
        };
        insert accounts;

        insert new Contact(FirstName = 'Grace', LastName = 'Hopper', AccountId = accounts[0].Id, Title = 'CTO');
        insert new Opportunity(
            Name = 'Alpha Expansion',
            AccountId = accounts[0].Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(45),
            Amount = 60000
        );
    }

    @IsTest
    static void searchInvocableReturnsMatches() {
        AccountSearchInvocable.Request req = new AccountSearchInvocable.Request();
        req.searchTerm = 'Invocable';

        Test.startTest();
        List<AccountSearchInvocable.Result> results = AccountSearchInvocable.search(
            new List<AccountSearchInvocable.Request>{ req }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'One result per request');
        Assert.isTrue(results[0].success, 'Search should succeed');
        Assert.areEqual(2, results[0].matchCount, 'Both Invocable accounts should match');
        Assert.areEqual('Invocable Alpha Corp', results[0].accounts[0].Name, 'Ordered by Name');
    }

    @IsTest
    static void searchInvocableHonoursMaxResults() {
        AccountSearchInvocable.Request req = new AccountSearchInvocable.Request();
        req.searchTerm = 'Invocable';
        req.maxResults = 1;

        List<AccountSearchInvocable.Result> results = AccountSearchInvocable.search(
            new List<AccountSearchInvocable.Request>{ req }
        );

        Assert.areEqual(1, results[0].matchCount, 'maxResults should cap the rows');
    }

    @IsTest
    static void searchInvocableReportsBlankTerm() {
        AccountSearchInvocable.Request req = new AccountSearchInvocable.Request();
        req.searchTerm = '';

        List<AccountSearchInvocable.Result> results = AccountSearchInvocable.search(
            new List<AccountSearchInvocable.Request>{ req }
        );

        Assert.isFalse(results[0].success, 'Blank term should fail');
        Assert.areEqual(0, results[0].matchCount, 'No matches on failure');
        Assert.isTrue(results[0].errorMessage.contains('required'), 'Error should explain the problem');
    }

    @IsTest
    static void searchInvocableHandlesBulkRequests() {
        AccountSearchInvocable.Request one = new AccountSearchInvocable.Request();
        one.searchTerm = 'Invocable Alpha';
        AccountSearchInvocable.Request two = new AccountSearchInvocable.Request();
        two.searchTerm = 'Outside';

        List<AccountSearchInvocable.Result> results = AccountSearchInvocable.search(
            new List<AccountSearchInvocable.Request>{ one, two }
        );

        Assert.areEqual(2, results.size(), 'One result per request');
        Assert.areEqual(1, results[0].matchCount, 'First request matched');
        Assert.areEqual('Outside The Search', results[1].accounts[0].Name, 'Second request matched');
    }

    @IsTest
    static void detailsInvocableReturnsRelatedRecords() {
        Account target = [SELECT Id FROM Account WHERE Name = 'Invocable Alpha Corp' LIMIT 1];
        AccountDetailsInvocable.Request req = new AccountDetailsInvocable.Request();
        req.accountId = target.Id;

        Test.startTest();
        List<AccountDetailsInvocable.Result> results = AccountDetailsInvocable.getDetails(
            new List<AccountDetailsInvocable.Request>{ req }
        );
        Test.stopTest();

        Assert.isTrue(results[0].success, 'Details should succeed');
        Assert.areEqual('Invocable Alpha Corp', results[0].accountRecord.Name, 'Correct account');
        Assert.isNotNull(results[0].ownerName, 'Owner name populated');
        Assert.areEqual(1, results[0].contacts.size(), 'Related contact returned');
        Assert.areEqual('CTO', results[0].contacts[0].Title, 'Contact title projected');
        Assert.areEqual(1, results[0].opportunities.size(), 'Related opportunity returned');
        Assert.areEqual(60000, results[0].opportunities[0].Amount, 'Opportunity amount projected');
    }

    @IsTest
    static void detailsInvocableResolvesByName() {
        AccountDetailsInvocable.Request req = new AccountDetailsInvocable.Request();
        req.accountName = 'Invocable Beta';

        List<AccountDetailsInvocable.Result> results = AccountDetailsInvocable.getDetails(
            new List<AccountDetailsInvocable.Request>{ req }
        );

        Assert.isTrue(results[0].success, 'Name lookup should succeed');
        Assert.areEqual('Invocable Beta Corp', results[0].accountRecord.Name, 'Correct account resolved');
        Assert.areEqual(0, results[0].contacts.size(), 'No related contacts expected');
    }

    @IsTest
    static void detailsInvocableReportsMissingAccount() {
        AccountDetailsInvocable.Request req = new AccountDetailsInvocable.Request();
        req.accountName = 'Nothing Matches This';

        List<AccountDetailsInvocable.Result> results = AccountDetailsInvocable.getDetails(
            new List<AccountDetailsInvocable.Request>{ req }
        );

        Assert.isFalse(results[0].success, 'Unmatched name should fail');
        Assert.isTrue(results[0].errorMessage.contains('No account found'), 'Error should explain the problem');
    }

    @IsTest
    static void detailsInvocableRejectsMalformedId() {
        AccountDetailsInvocable.Request req = new AccountDetailsInvocable.Request();
        req.accountId = 'nope';

        List<AccountDetailsInvocable.Result> results = AccountDetailsInvocable.getDetails(
            new List<AccountDetailsInvocable.Request>{ req }
        );

        Assert.isFalse(results[0].success, 'Malformed Id should fail');
        Assert.isTrue(results[0].errorMessage.contains('not a valid Salesforce Id'), 'Error should name the problem');
    }

    @IsTest
    static void detailsInvocableBulkifiesRelatedQueries() {
        List<Account> targets = [SELECT Id FROM Account WHERE Name LIKE 'Invocable%' ORDER BY Name];
        List<AccountDetailsInvocable.Request> requests = new List<AccountDetailsInvocable.Request>();
        for (Account a : targets) {
            AccountDetailsInvocable.Request req = new AccountDetailsInvocable.Request();
            req.accountId = a.Id;
            requests.add(req);
        }

        Test.startTest();
        List<AccountDetailsInvocable.Result> results = AccountDetailsInvocable.getDetails(requests);
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'One result per request');
        Assert.areEqual(1, results[0].contacts.size(), 'Alpha keeps its contact');
        Assert.areEqual(0, results[1].contacts.size(), 'Beta has none');
        // 2 account lookups + 1 contact query + 1 opportunity query.
        Assert.areEqual(4, queriesUsed, 'Related records should load in two bulk queries');
    }

    @IsTest
    static void selectorTreatsWildcardsLiterally() {
        insert new Account(Name = '50% Off Supplies');

        List<Account> rows = AccountMcpSelector.searchByName('50%', null);

        Assert.areEqual(1, rows.size(), 'A literal % should not act as a wildcard');
        Assert.areEqual('50% Off Supplies', rows[0].Name, 'Correct account matched');
    }

    @IsTest
    static void selectorClampsLimits() {
        Assert.areEqual(10, AccountMcpSelector.normalizeLimit(null), 'Null falls back to the default');
        Assert.areEqual(10, AccountMcpSelector.normalizeLimit(0), 'Zero falls back to the default');
        Assert.areEqual(200, AccountMcpSelector.normalizeLimit(5000), 'Oversized requests clamp to the max');
        Assert.areEqual(25, AccountMcpSelector.normalizeLimit(25), 'In-range values pass through');
        Assert.areEqual(10, AccountMcpSelector.parseLimit('garbage'), 'Unparseable strings fall back');
        Assert.areEqual(7, AccountMcpSelector.parseLimit('7'), 'Numeric strings parse');
    }
}