SELECT
  _id,
  person.name.firstName,
  _cognizanttechnologys.loyaltyTierMP,
  _cognizanttechnologys.loyaltyPoints
FROM
  "my_customer_dataset_mp_20260629_190845_480"
WHERE
  _cognizanttechnologys.loyaltyTierMP = 'Gold'