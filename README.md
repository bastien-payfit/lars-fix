# Purpose
The purpose of this document is to guide readers through our multiple sql requests and to present our key results.

# Acknowledgements
- All LARs that need a fix **have an assignment date**,
- All LARs that need a fix **have an end relation date**
Because Lucas and I made sure of it during previous LAR recovery sessions.

# Vocabulary
- **backlog**: LARs waiting for an assignment. Those LARs are characterized by the absence of owner AND assignment date on their record (simultaneously).

# Walkthrough

### 1. Lars to fix
Find LARs to fix by executing the queries in `lars_to_fix.sql`. _LARs to fix are those not in [backlog](#Vocabulary) with no owner_.

### 2. Counts
Execute the queries in `counts.sql` to grasp the volumes we're dealing with and how many lars we have to fix. You'll find the following:
- **Total number of LARs**: 79 796
- **Number of LARs not in backlog**: 71 552
- **Number of LARs in backlog**: 8 244
- **Number of LARs to fix**: 17 904

### 3. Account history
To find missing owners, we thought about using `accounthistory`. Meaning that, for a given LAR, active on a given time frame, we want to find the owner of the account linked to the LAR on the given time frame.

First, look at the account history by executing queries in `account_history.sql`. You'll notice that we excluded changes that did not occur on the *owner* field, and changes to 'Outbound database' or any 'Reassignment Pools' (because these changes do not alter the owner of the LAR).

### 4. Join LARs & Account History
If we want to find missing LAR owners, we have to join LARs and Account History and we should have as many LARs to fix (17 904) even after the join with the account history. Unfortunately, that's not the case...

When we execute this query 👇 in `lars_to_fix_&_account_history.sql` we find only 8 388 LARs to fix.
```sql
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
)
SELECT 
    count(*) tot_nb_lines,
    count(distinct lars_to_fix.id) nb_lars_to_fix
FROM lars_to_fix
JOIN history 
    on lars_to_fix.account__c = history.accountid;
```

That means that some LARs to fix are linked to accounts with no history available in accounthistory - assertion confirmed by the following query in `lars_to_fix_&_account_history.sql`👇

```sql
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
)
SELECT 
    count(distinct lars_to_fix.id) nb_lars_w_no_history
FROM lars_to_fix
LEFT JOIN history 
    on lars_to_fix.account__c = history.accountid
WHERE history.accountid is null;
```

We find that 9 516 LARs are linked to accounts with no available history on their owners. Thorough readers will notice that 8 388 + 9 516 = 17 904, the total number of LARs left to fix.

### 5. Find missing owners
Let's ignore the issues stated [above](#4.-Join-LARs-&-Account-History) for a moment and do as if we could find all the missing owners. Let's move on to `larOwners.sql` and execute its multiple queries.

You will find this particular query interesting 👇
```sql
-- @block Ower comparison
WITH lars AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND assignement_date__c is not null
        AND owner_relation__c is not null
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
)
SELECT 
    COUNT(distinct lars.id) total,
    SUM(case when lars.owner_relation__c = history.newvalue__string then 1 else 0 end) lar_owner_is_account_owner
FROM lars
JOIN history 
    on lars.account__c = history.accountid 
    and history.createddate >= lars.assignement_date__c
    and (history.createddate <= lars.end_relation_date__c or lars.end_relation_date__c is null);
```

We find that on all LARs that already have an owner (there are 34 135 of them), the LAR owner name matches the owner we found in account history in only 32 389 cases (that's still more than 90% - fair enough).

Recovering owner names thanks to the account history was never anything more than a hypothesis (that needed validation). Let's assume that the 90% success rate on LARs that already have an owner is enough to validate this hypothesis. Let's now pretend to carry on and try to to recover LARs **missing owner names**.

To do that, we'd run this query 👇 (You'll notice that 72 LARs have been excluded in the long list at the end of the query - check [this message](https://payfit.slack.com/archives/C019JGWPHSR/p1619018500009500) on Slack if that makes no sense)
```sql
-- @block Nb owners per LAR to fix
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
)
SELECT 
    distinct lars_to_fix.id, 
    count(*) nb_attribution
FROM lars_to_fix
JOIN history 
    on lars_to_fix.account__c = history.accountid
    and history.createddate >= lars_to_fix.assignement_date__c
    and (history.createddate <= lars_to_fix.end_relation_date__c or lars_to_fix.end_relation_date__c is null)
WHERE
    lars_to_fix.id not in ('a0v3X00000f1e16QAA','a0v3X00000f1fyfQAA','a0v3X00000f3qJhQAI','a0v3X00000f3qJcQAI','a0v3X00000f3pwCQAQ','a0v3X00000f3pwHQAQ','a0v3X00000f3og7QAA','a0v3X00000f3ogHQAQ','a0v3X00000f4QmwQAE','a0v3X00000f4QmrQAE','a0v3X00000f4R3sQAE','a0v3X00000f4R3tQAE','a0v3X00000f4UwTQAU','a0v3X00000f4Uw7QAE','a0v3X00000f3ouJQAQ','a0v3X00000f3ouOQAQ','a0v3X00000f4UwGQAU','a0v3X00000f4UwHQAU','a0v3X00000f3ot6QAA','a0v3X00000f3otBQAQ','a0v3X00000f1kWlQAI','a0v3X00000f1kWoQAI','a0v3X00000f3o7SQAQ','a0v3X00000f3o7XQAQ','a0v3X00000f4PjiQAE','a0v3X00000f4PkFQAU','a0v3X00000f2okrQAA','a0v3X00000f2ooPQAQ','a0v3X00000f3qGEQAY','a0v3X00000f3qG9QAI','a0v3X00000f3qDtQAI','a0v3X00000f3qDyQAI','a0v3X00000f2pRaQAI','a0v3X00000f2pRQQAY','a0v3X00000f2ww9QAA','a0v3X00000f2wzSQAQ','a0v3X00000f4QXzQAM','a0v3X00000f4QXZQA2','a0v3X00000f4PlYQAU','a0v3X00000f4PlDQAU','a0v3X00000f4T3EQAU','a0v3X00000f4T3JQAU','a0v3X00000f4PLkQAM','a0v3X00000f4PLpQAM','a0v3X00000f2oWpQAI','a0v3X00000f2oWuQAI','a0v3X00000f2oWkQAI','a0v3X00000f2wNrQAI','a0v3X00000f2wIgQAI','a0v3X00000f3oNIQAY','a0v3X00000f3oREQAY','a0v3X00000f4PkBQAU','a0v3X00000f4PkdQAE','a0v3X00000f4TBRQA2','a0v3X00000f4TFoQAM','a0v3X00000f4PjcQAE','a0v3X00000f4PjTQAU','a0v3X00000f4PjLQAU','a0v3X00000f4PkQQAU','a0v3X00000f4OijQAE','a0v3X00000f4OioQAE','a0v3X00000f4PjfQAE','a0v3X00000f4PjxQAE','a0v3X00000f2ySYQAY','a0v3X00000f2yTMQAY','a0v3X00000f2ySdQAI','a0v3X00000f4QiiQAE','a0v3X00000f4QinQAE','a0v3X00000f2u0aQAA','a0v3X00000f2uDDQAY','a0v3X00000f4PbaQAE','a0v3X00000f4PbVQAU')
GROUP BY 1;
```
Then you'll notice that **there are still a few LARs without owners that have multiple owners in the associated account history** on the given assignment time frame. Once again, that should raise some eyebrows, like it id on the meeting of April, 14th.

We can even go a step further and execute this query 👇
```sql
-- @block Nb lars x Nb of owners
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
    COUNT(nb_owners.lar_id),
    SUM(case when nb_assignments = 1 then 1 else 0 end) nb_one_assignment,
    SUM(case when nb_assignments = 2 then 1 else 0 end) nb_two_assignments,
    SUM(case when nb_assignments = 3 then 1 else 0 end) nb_three_assignments,
    SUM(case when nb_assignments > 3 then 1 else 0 end) nb_more_than_three_assignments
FROM nb_owners;
```
Among LARs that need a fix on their owner:
- We found a single owner on the time frame for **6323** of them,
- We found two owners on the time frame for **596** of them,
- We found a three owners on the time frame for **61** of them,
- And finally, we found more than three owners for **19** of them.

At this point, one should ask:
> Is there still something going on with end_relation_dates?

We were supposed to fix them with Lucas but I guess now is time to double check.

### 6. Do we have all the end relation dates we need?
Let's move on to `end_relation_dates.sql`and its queries. First, we find 20 lars for which we found more than 2 owners in the accounthistory 👇
```sql
-- @block Find a few lar ids for which we discovered more than two owners.
WITH lars_to_fix AS (
...
SELECT 
    lar_id
FROM nb_owners
WHERE nb_assignments > 1
LIMIT 20;
```

Then we find the accounts associated to those specific lars 👇
```sql
-- @block find accounts associated to the dozen of lars above
SELECT 
    distinct account__c
FROM staging_salesforce.batchaccountrelation__c bc
WHERE bc.id in ('a0v3X00000f1eE3QAI','a0v3X00000f1jTsQAI','a0v3X00000f4UnBQAU','a0v3X00000f4WKxQAM','a0v3X00000f1kDoQAI','a0v3X00000f3q0YQAQ','a0v3X00000f4UlDQAU','a0v3X00000f4UuQQAU','a0v3X00000f4WLIQA2','a0v3X00000f29VAQAY','a0v3X00000f4UrMQAU','a0v3X00000f4UnVQAU','a0v3X00000f4UsFQAU','a0v3X00000gEwOtQAK','a0v3X00000f1jckQAA','a0v3X00000f1g0sQAA','a0v3X00000gExvqQAC','a0v3X00000f28HXQAY','a0v3X00000f4QfWQAU','a0v3X00000f4QfOQAU');
```
Finally - and that concludes our investigation - we find all the lars associated to one of the accounts found thanks to the query above 👇
```sql
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
```
👉 We find 4 LARs on this account ([also on Salesforce](https://payfit.lightning.force.com/lightning/r/Account/0013X00002wGVyCQAW/view?ws=%2Flightning%2Fr%2FBatchAccountRelation__c%2Fa0v3X00000f1eE3QAI%2Fview)) and most importantly, we find that the first LAR does not have an end relation date.

> Lucas and I did not manage to recover every end relation dates after all...

# Conclusion

We still can't recover the missing LAR owner names because:
1. Among the 17 904 LARs to fix, only 8 388 of them have an account history ([cf. section 4](4.-Join-LARs-&-Account-History))
2. Among these, some still don't have end relation dates when they should ([cf.  previous section](6.-Do-we-have-all-the-end-relation-dates-we-need?))

We can fix 2. if need be but I don't see how we can put up with 1: even if we fixed the 8 388 LARs we have, that would make little sense in a dashboard.