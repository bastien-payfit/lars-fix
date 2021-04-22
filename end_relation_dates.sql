-- @block Find a few lar ids for which we discovered more than two owners.
WITH lars_to_fix AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND assignement_date__c IS NOT NULL
        AND owner_relation__c IS NULL
),
history AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string <> newvalue__string 
        and oldvalue__string not like '0053X%'
        and newvalue__string <> 'Outbound Database' 
        and newvalue__string not like '%Reassignment%'
),
nb_owners AS (
    SELECT 
        distinct lars_to_fix.id as lar_id,
        count(*) nb_assignments
    FROM lars_to_fix
    JOIN history 
        on lars_to_fix.account__c = history.accountid
        and history.createddate >= lars_to_fix.assignement_date__c
        and (history.createddate <= lars_to_fix.end_relation_date__c or lars_to_fix.end_relation_date__c is null)
    WHERE
        lars_to_fix.id not in ('a0v3X00000f1e16QAA','a0v3X00000f1fyfQAA','a0v3X00000f3qJhQAI','a0v3X00000f3qJcQAI','a0v3X00000f3pwCQAQ','a0v3X00000f3pwHQAQ','a0v3X00000f3og7QAA','a0v3X00000f3ogHQAQ','a0v3X00000f4QmwQAE','a0v3X00000f4QmrQAE','a0v3X00000f4R3sQAE','a0v3X00000f4R3tQAE','a0v3X00000f4UwTQAU','a0v3X00000f4Uw7QAE','a0v3X00000f3ouJQAQ','a0v3X00000f3ouOQAQ','a0v3X00000f4UwGQAU','a0v3X00000f4UwHQAU','a0v3X00000f3ot6QAA','a0v3X00000f3otBQAQ','a0v3X00000f1kWlQAI','a0v3X00000f1kWoQAI','a0v3X00000f3o7SQAQ','a0v3X00000f3o7XQAQ','a0v3X00000f4PjiQAE','a0v3X00000f4PkFQAU','a0v3X00000f2okrQAA','a0v3X00000f2ooPQAQ','a0v3X00000f3qGEQAY','a0v3X00000f3qG9QAI','a0v3X00000f3qDtQAI','a0v3X00000f3qDyQAI','a0v3X00000f2pRaQAI','a0v3X00000f2pRQQAY','a0v3X00000f2ww9QAA','a0v3X00000f2wzSQAQ','a0v3X00000f4QXzQAM','a0v3X00000f4QXZQA2','a0v3X00000f4PlYQAU','a0v3X00000f4PlDQAU','a0v3X00000f4T3EQAU','a0v3X00000f4T3JQAU','a0v3X00000f4PLkQAM','a0v3X00000f4PLpQAM','a0v3X00000f2oWpQAI','a0v3X00000f2oWuQAI','a0v3X00000f2oWkQAI','a0v3X00000f2wNrQAI','a0v3X00000f2wIgQAI','a0v3X00000f3oNIQAY','a0v3X00000f3oREQAY','a0v3X00000f4PkBQAU','a0v3X00000f4PkdQAE','a0v3X00000f4TBRQA2','a0v3X00000f4TFoQAM','a0v3X00000f4PjcQAE','a0v3X00000f4PjTQAU','a0v3X00000f4PjLQAU','a0v3X00000f4PkQQAU','a0v3X00000f4OijQAE','a0v3X00000f4OioQAE','a0v3X00000f4PjfQAE','a0v3X00000f4PjxQAE','a0v3X00000f2ySYQAY','a0v3X00000f2yTMQAY','a0v3X00000f2ySdQAI','a0v3X00000f4QiiQAE','a0v3X00000f4QinQAE','a0v3X00000f2u0aQAA','a0v3X00000f2uDDQAY','a0v3X00000f4PbaQAE','a0v3X00000f4PbVQAU')
    GROUP BY 1
)
SELECT 
    lar_id
FROM nb_owners
WHERE nb_assignments > 1
LIMIT 20;

-- @block find accounts associated to the dozen of lars above
SELECT 
    distinct account__c
FROM staging_salesforce.batchaccountrelation__c bc
WHERE bc.id in ('a0v3X00000f1eE3QAI','a0v3X00000f1jTsQAI','a0v3X00000f4UnBQAU','a0v3X00000f4WKxQAM','a0v3X00000f1kDoQAI','a0v3X00000f3q0YQAQ','a0v3X00000f4UlDQAU','a0v3X00000f4UuQQAU','a0v3X00000f4WLIQA2','a0v3X00000f29VAQAY','a0v3X00000f4UrMQAU','a0v3X00000f4UnVQAU','a0v3X00000f4UsFQAU','a0v3X00000gEwOtQAK','a0v3X00000f1jckQAA','a0v3X00000f1g0sQAA','a0v3X00000gExvqQAC','a0v3X00000f28HXQAY','a0v3X00000f4QfWQAU','a0v3X00000f4QfOQAU');

-- @block end_relation_dates on lars associated to one of the accounts found above ('0013X00002wGVyCQAW')
SELECT
    id,
    account__c, 
    assignement_date__c,
    end_relation_date__c,
    owner_relation__c
FROM staging_salesforce.batchaccountrelation__c bc
WHERE
    bc.account__c ='0013X00002wGVyCQAW'
ORDER BY assignement_date__c DESC;