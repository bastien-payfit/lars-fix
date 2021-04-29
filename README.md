# Purpose
The purpose of this document is to guide readers through our multiple sql requests and to present our key results.

# Acknowledgements
- All LARs that need a fix **have an assignment date**,
- All LARs that need a fix **have an end relation date**
Because Lucas and I made sure of it during previous LAR recovery sessions.

# Vocabulary
- **backlog**: LARs waiting for an assignment. Those LARs are characterized by the absence of owner AND assignment date on their record (simultaneously).

___
>If you're already bored and in a for-the-love-of-god-what-did-you-guys-actually-do mood, then jump to [this part](#Final-Results).


# Walkthrough

### **1. Lars to fix**
Find LARs to fix by executing the queries in `lars_to_fix.sql`. _LARs to fix are those not in [backlog](#Vocabulary) with no owner_.

### **2. Counts**
Execute the queries in `counts.sql` to grasp the volumes we're dealing with and how many lars we have to fix. You'll find the following:
- **Total number of LARs**: 79 796
- **Number of LARs not in backlog**: 71 552
- **Number of LARs in backlog**: 8 244
- **Number of LARs to fix**: 17 904

### **3. Account history**
To find missing owners, we thought about using `accounthistory`. Meaning that, for a given LAR, active on a given time frame, we want to find the owner of the account linked to the LAR on the given time frame.

First, look at the account history by executing queries in `account_history.sql`. You'll notice that we excluded changes that did not occur on the *owner* field, and changes to 'Outbound database' or any 'Reassignment Pools' (because these changes do not alter the owner of the LAR).

### **4. Join LARs & Account History**
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

> "Dear Lord, isn't there anything we can do?"

> "There might..."

___
Gauvain suggested that those 9 516 LARs had no owner changes recorded in accounthistory merely because the owner on the associated accounts had never changed since their creation.

Consequently, on those LARs, the LAR owner would be the only owner there ever was on the associated account. If we're to validate this hypothesis, we must try it on **LARs that already have an owner but no owner change recorded in the account history of their associated account**. 

Therefore, switch back to the next query of `lars_to_fix_&_account_history.sql` - let's break it down!

1. First, we select LARs that already have an owner:
```sql
WITH lars_w_owner AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND owner_relation__c IS NOT NULL
),
```
2. Then the account history of a change of owner:
```sql
history1 AS (
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
```
3. Then LARs that have an owner but no owner changes recorded in their account history:
```sql
lars_w_owner_no_history AS (
    SELECT 
        lars_w_owner.id,
        lars_w_owner.account__c,
        lars_w_owner.owner_relation__c
    FROM lars_w_owner
    LEFT JOIN history1 
        on lars_w_owner.account__c = history1.accountid
    WHERE history1.accountid is null
),
```
4. Then all the account history available (*we don't filter on owner changes anymore*, compare it to history1 if you're not sure):
```sql
history2 AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string not like '0053X%'
        and oldvalue__string <> 'Outbound Database' 
        and oldvalue__string not like '%Reassignment%'
)
```
5. Finally we join LARs with an owner, and no owner changes recorded, to the whole unfiltered account history:
```sql
SELECT
    lars_w_owner_no_history.*,
    history2.* 
FROM lars_w_owner_no_history
JOIN history2 
ON lars_w_owner_no_history.account__c = history2.accountid
;
```
And... **HURRAY**! The LAR owners match the *oldvalue__string* of the accounthistory after the join 🎉 Run the query and see for yourself!
___
Let's sum it up!

In this scenario, for all 17 904 LARs to fix, there would be two distinct outcomes:
- If we have owner changes recorded in the account history, then we use the method envisioned hitherto,
- If not, we take the first recorded owner in the account history.

In other words, the 8 388 LARs will be fixed with the first method, and the 9 516 others with the latter. Consequently, we have to make sure that all 9 516 LARs that *would be* fixed with the second method actually have a first owner recorded in *accounthistory*. 

### **5. Finding owners that have owner changes recorded**
Let's move on to `lar_owners.sql` and execute its multiple queries.

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

Then, we'd run this query to make sure that - this time - there's only one owner on the assignment time frame of the LAR 👇 (You'll notice that 72 LARs have been excluded in the long list at the end of the query - check [this message](https://payfit.slack.com/archives/C019JGWPHSR/p1619018500009500) on Slack if that makes no sense)
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
- We find a single owner on the time frame for **6323** of them,
- We find two owners on the time frame for **596** of them,
- We find a three owners on the time frame for **61** of them,
- And finally, we find more than three owners for **19** of them.

**That's not enough**

At this point, one should ask:
> Is there still something going on with end_relation_dates?

We were supposed to fix them with Lucas but I guess we'll have to double check (see this [this section](7.-Do-we-have-all-the-end-relation-dates-we-need?)).

### **6. Finding owners when no owner changes recorded**

Let's ignore the end_relation_date issue for the moment and move on to the last request of `lar_owners.sql` 👇

You'll note that LARs to fix (with no owner) with no history are all encompassed in the first temporary table:

```sql
-- @block Can we find missing owners in unfiltered account history when no owner changes recorded
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
history1 AS (
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
lars_to_fix_no_history AS (
    SELECT 
        lars_to_fix.id,
        lars_to_fix.account__c,
        lars_to_fix.owner_relation__c
    FROM lars_to_fix
    LEFT JOIN history1 
        on lars_to_fix.account__c = history1.accountid
    WHERE history1.accountid is null
),
history2 AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string not like '0053X%'
        and oldvalue__string <> 'Outbound Database' 
        and oldvalue__string not like '%Reassignment%'
)
SELECT
    count(distinct lars_to_fix_no_history.id)
FROM lars_to_fix_no_history
JOIN history2 
ON lars_to_fix_no_history.account__c = history2.accountid
;
```

We find an owner for only 4 872 of the 9 516 remaining LARs. In an ideal world,

**that's not enough**

### 7. Do we have all the end relation dates we need?
It's time to roll back to the end_relation_date issue. Go to `end_relation_dates.sql` and its queries. First, we find 20 lars for which we found more than 2 owners in the accounthistory 👇
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

# Key findings

1. Among the 17 904 LARs to fix, only 8 388 of them have an account history ([cf. section 4](4.-Join-LARs-&-Account-History)) and among the remaining 9 516, only 4 872 have a first owner we can recover. That's 4.5K+ we can't account for.
2. Among the 8 388, some still don't have end relation dates when they should ([cf.  previous section](6.-Do-we-have-all-the-end-relation-dates-we-need?))

# Final Results
1. Lucas and I recovered **all** end relation dates. There's a series of queries in `fix_end_relation_dates.sql` 👉 we proceeded on a few extra steps in GSheet that provides a better UI than mere sql requests. [Here's the document](https://docs.google.com/spreadsheets/d/1GJt3Q4QNuSGhMAPgw6mfu8Qq7b-W3NIvXdwKK1U19yk/edit#gid=150558237) with updated LARs' end relation dates.
2. Then, we fixed all LARs with recorded owner changes. Among the 8 388 in total, **we could fix only 6 451** because others still had multiple owner possibilities, even after the end relation date fix. The only query is the first one in `fix_owners.sql` and [here's the final document](https://docs.google.com/spreadsheets/d/1FJIPSPy-fnwKtHAAqse3GMzgGc5UspaxjBdIJShWr5c/edit#gid=61716283).
3. Afterwards, we fixed LARs with no recorded owner changes, just by taking the oldest value there was in the account history for an owner. The only query is the second one in `fix_owners.sql`. The final document is [here](https://docs.google.com/spreadsheets/d/1FJIPSPy-fnwKtHAAqse3GMzgGc5UspaxjBdIJShWr5c/edit#gid=898532762). As stated above, among the 9 516 LARs with no owner changes recorded, **we could only fix 4 872** of them.