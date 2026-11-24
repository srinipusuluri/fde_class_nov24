@IsTest
private class AccountMcpServiceTest {
    private static final String BASE_URI = '/services/apexrest/mcp/accounts';

    @TestSetup
    static void setup() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Zenith Test Labs', Industry = 'Biotechnology', Rating = 'Hot', AnnualRevenue = 500000),
            new Account(Name = 'Zenith Test Holdings', Industry = 'Finance', Rating = 'Warm', AnnualRevenue = 900000),
            new Account(Name = 'Unrelated Widgets', Industry = 'Retail')
        };
        insert accounts;

        insert new Contact(FirstName = 'Ada', LastName = 'Lovelace', AccountId = accounts[0].Id, Email = 'ada@example.com');
        insert new Opportunity(
            Name = 'Zenith Renewal',
            AccountId = accounts[0].Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 25000
        );
    }

    private static void request(String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';
        if (params != null) {
            req.params.putAll(params);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void searchReturnsMatchesByPartialName() {
        request(BASE_URI + '/search', new Map<String, String>{ 'name' => 'Zenith' });

        Test.startTest();
        AccountMcpService.ApiResponse res = AccountMcpService.doGet();
        Test.stopTest();

        Assert.isTrue(res.success, 'Search should succeed');
        Assert.areEqual(2, res.count, 'Both Zenith accounts should match');
        Assert.areEqual('Zenith Test Holdings', res.accounts[0].name, 'Results should be ordered by Name');
        Assert.areEqual('Finance', res.accounts[0].industry, 'Industry should be projected');
    }

    @IsTest
    static void searchHonoursMaxParameter() {
        request(BASE_URI + '/search', new Map<String, String>{ 'name' => 'Zenith', 'max' => '1' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.areEqual(1, res.count, 'max=1 should cap the result set');
    }

    @IsTest
    static void searchFallsBackToDefaultLimitOnBadMax() {
        request(BASE_URI + '/search', new Map<String, String>{ 'name' => 'Zenith', 'max' => 'not-a-number' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isTrue(res.success, 'A malformed max should not fail the request');
        Assert.areEqual(2, res.count, 'Default limit should apply');
    }

    @IsTest
    static void searchRequiresNameParameter() {
        request(BASE_URI + '/search', null);

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isFalse(res.success, 'Missing name should fail');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should report a 400');
    }

    @IsTest
    static void searchTreatsWildcardsLiterally() {
        insert new Account(Name = '100% Pure Co');
        request(BASE_URI + '/search', new Map<String, String>{ 'name' => '100%' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.areEqual(1, res.count, 'A literal % should not act as a wildcard');
        Assert.areEqual('100% Pure Co', res.accounts[0].name, 'Should match the literal name');
    }

    @IsTest
    static void detailsByIdReturnsRelatedRecords() {
        Account target = [SELECT Id FROM Account WHERE Name = 'Zenith Test Labs' LIMIT 1];
        request(BASE_URI + '/details', new Map<String, String>{ 'id' => target.Id });

        Test.startTest();
        AccountMcpService.ApiResponse res = AccountMcpService.doGet();
        Test.stopTest();

        Assert.isTrue(res.success, 'Details should succeed');
        Assert.areEqual('Zenith Test Labs', res.detail.account.name, 'Correct account returned');
        Assert.areEqual(1, res.detail.contacts.size(), 'Related contact returned');
        Assert.areEqual('Ada Lovelace', res.detail.contacts[0].name, 'Contact name projected');
        Assert.areEqual(1, res.detail.opportunities.size(), 'Related opportunity returned');
        Assert.areEqual(25000, res.detail.opportunities[0].amount, 'Opportunity amount projected');
        Assert.isNotNull(res.detail.ownerName, 'Owner name should be populated');
    }

    @IsTest
    static void detailsByNameResolvesAccount() {
        request(BASE_URI + '/details', new Map<String, String>{ 'name' => 'Unrelated' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isTrue(res.success, 'Lookup by partial name should succeed');
        Assert.areEqual('Unrelated Widgets', res.detail.account.name, 'Correct account resolved');
        Assert.areEqual(0, res.detail.contacts.size(), 'No related contacts expected');
    }

    @IsTest
    static void detailsReturns404WhenNameHasNoMatch() {
        request(BASE_URI + '/details', new Map<String, String>{ 'name' => 'No Such Account Anywhere' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isFalse(res.success, 'Unmatched name should fail');
        Assert.areEqual(404, RestContext.response.statusCode, 'Should report a 404');
    }

    @IsTest
    static void detailsRejectsMalformedId() {
        request(BASE_URI + '/details', new Map<String, String>{ 'id' => 'not-an-id' });

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isFalse(res.success, 'Malformed Id should fail');
        Assert.isTrue(res.error.contains('not a valid Salesforce Id'), 'Error should explain the problem');
    }

    @IsTest
    static void detailsRequiresIdOrName() {
        request(BASE_URI + '/details', null);

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isFalse(res.success, 'Missing both params should fail');
        Assert.areEqual(400, RestContext.response.statusCode, 'Should report a 400');
    }

    @IsTest
    static void unknownActionIsRejected() {
        request(BASE_URI + '/frobnicate', null);

        AccountMcpService.ApiResponse res = AccountMcpService.doGet();

        Assert.isFalse(res.success, 'Unknown action should fail');
        Assert.isTrue(res.error.contains('Unknown action'), 'Error should name the problem');
    }
}