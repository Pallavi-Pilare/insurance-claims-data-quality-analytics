# ============================================================
# Insurance Claims Data Quality Analysis
# Author      : Pallavi Pilare
# Date        : 2026
# Tools       : Python (pandas, matplotlib, seaborn)
# ============================================================

# ── STEP 1: Import Libraries ─────────────────────────────────
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

print("=" * 60)
print("  DAVIES GROUP — INSURANCE CLAIMS DATA QUALITY ANALYSIS")
print("=" * 60)


# ── STEP 2: Load Dataset ─────────────────────────────────────
print("\n[STEP 2] Loading Dataset...")
df = pd.read_csv('data/insurance_claims.csv')
print(f"  Shape        : {df.shape[0]} rows x {df.shape[1]} columns")
print(f"  Columns      : {list(df.columns)}")
print(f"\n{df.head(5).to_string()}")


# ── STEP 3: Data Quality Check ───────────────────────────────
print("\n[STEP 3] Data Quality Checks")
print("-" * 40)

# 3.1 Missing Values
print("\n  3.1 Missing Values:")
missing = df.isnull().sum()
missing_pct = (missing / len(df) * 100).round(2)
missing_report = pd.DataFrame({
    'Missing Count': missing,
    'Missing %': missing_pct
}).query('`Missing Count` > 0')
print(missing_report.to_string())

# 3.2 Duplicate Claim IDs
dupe_count = df['claim_id'].duplicated().sum()
print(f"\n  3.2 Duplicate Claim IDs  : {dupe_count}")
if dupe_count > 0:
    dupes = df[df['claim_id'].duplicated(keep=False)][['claim_id','claim_date','claim_amount']].head(10)
    print(dupes.to_string())

# 3.3 Invalid Date Formats
df['claim_date_parsed'] = pd.to_datetime(df['claim_date'], errors='coerce')
invalid_dates = df['claim_date_parsed'].isna().sum()
print(f"\n  3.3 Invalid/Unparseable Dates : {invalid_dates}")

# 3.4 Future Dates
future = (df['claim_date_parsed'] > pd.Timestamp.today()).sum()
print(f"\n  3.4 Future Claim Dates (Invalid) : {future}")

# 3.5 Negative/Zero Amounts
bad_amounts = (df['claim_amount'] <= 0).sum()
print(f"\n  3.5 Invalid Claim Amounts (<= 0) : {bad_amounts}")

# 3.6 Data Quality Score
total = len(df)
issues = missing['claim_amount'] + dupe_count + invalid_dates + future
dq_score = round(100 * (1 - issues / (total * 2)), 2)
print(f"\n  ★  Overall Data Quality Score : {dq_score}%")


# ── STEP 4: Data Cleaning ────────────────────────────────────
print("\n[STEP 4] Data Cleaning & Correction")
print("-" * 40)

df_clean = df.copy()

# Fix dates
df_clean['claim_date'] = pd.to_datetime(df_clean['claim_date'], errors='coerce')

# Fill missing amounts with median of same claim_type
before = df_clean['claim_amount'].isna().sum()
df_clean['claim_amount'] = df_clean.groupby('claim_type')['claim_amount'].transform(
    lambda x: x.fillna(x.median())
)
after = df_clean['claim_amount'].isna().sum()
print(f"  Missing amounts filled   : {before - after} records corrected")

# Remove duplicates (keep first)
before_rows = len(df_clean)
df_clean = df_clean.drop_duplicates(subset='claim_id', keep='first')
print(f"  Duplicate rows removed   : {before_rows - len(df_clean)} records")

# Remove future dates
df_clean = df_clean[df_clean['claim_date'] <= pd.Timestamp.today()]
print(f"  Future dates removed     : records filtered")

print(f"\n  Clean Dataset Shape : {df_clean.shape}")
df_clean.to_csv('data/insurance_claims_cleaned.csv', index=False)
print("  Cleaned file saved  : data/insurance_claims_cleaned.csv")


# ── STEP 5: Exploratory Data Analysis ───────────────────────
print("\n[STEP 5] Exploratory Data Analysis")
print("-" * 40)

# 5.1 Descriptive Stats
print("\n  5.1 Descriptive Statistics:")
print(df_clean[['claim_amount','settlement_days','customer_age']].describe().round(2).to_string())

# 5.2 Claims by Status
print("\n  5.2 Claims by Status:")
status_summary = df_clean.groupby('claim_status').agg(
    Count=('claim_id','count'),
    Total_Amount=('claim_amount','sum'),
    Avg_Amount=('claim_amount','mean')
).round(2)
print(status_summary.to_string())

# 5.3 Handler Performance
print("\n  5.3 Handler Performance:")
handler_perf = df_clean.groupby('handler').agg(
    Total_Assigned=('claim_id','count'),
    Closed=('claim_status', lambda x: (x=='Closed').sum()),
    Avg_Settlement_Days=('settlement_days','mean')
).round(1)
handler_perf['Closure_Rate_%'] = (
    handler_perf['Closed'] / handler_perf['Total_Assigned'] * 100
).round(2)
print(handler_perf.to_string())

# 5.4 Fraud Analysis
print("\n  5.4 Fraud Flag Analysis:")
fraud = df_clean.groupby('claim_type').agg(
    Total=('claim_id','count'),
    Fraud_Cases=('fraud_flag','sum'),
    Fraud_Amount=('claim_amount', lambda x: x[df_clean.loc[x.index,'fraud_flag']==1].sum())
).round(2)
fraud['Fraud_Rate_%'] = (fraud['Fraud_Cases'] / fraud['Total'] * 100).round(2)
print(fraud.to_string())


# ── STEP 6: Month-End Report ─────────────────────────────────
print("\n[STEP 6] Month-End Report Generation")
print("-" * 40)

df_clean['month'] = df_clean['claim_date'].dt.to_period('M')
month_report = df_clean.groupby('month').agg(
    Total_Claims=('claim_id','count'),
    Total_Amount=('claim_amount','sum'),
    Avg_Amount=('claim_amount','mean'),
    Closed=('claim_status', lambda x: (x=='Closed').sum()),
    Open=('claim_status', lambda x: (x=='Open').sum()),
    Fraud_Cases=('fraud_flag','sum')
).round(2)
print(month_report.to_string())
month_report.to_csv('reports/month_end_report.csv')
print("\n  Month-End Report saved : reports/month_end_report.csv")


# ── STEP 7: QA Validation Summary ───────────────────────────
print("\n[STEP 7] QA Validation Summary (Audit Ready)")
print("-" * 40)

qa_summary = {
    'Total Records Received'    : total,
    'Records After Cleaning'    : len(df_clean),
    'Missing Values Fixed'      : before - after,
    'Duplicates Removed'        : before_rows - len(df_clean),
    'Invalid Dates Removed'     : invalid_dates,
    'Fraud Cases Identified'    : int(df_clean['fraud_flag'].sum()),
    'Total Claim Value (Clean)' : f"INR {df_clean['claim_amount'].sum():,.2f}",
    'Data Quality Score'        : f"{dq_score}%",
    'SLA Breaches (>90 days)'   : int((df_clean['settlement_days'] > 90).sum()),
}
for k, v in qa_summary.items():
    print(f"  {k:<35}: {v}")

print("\n" + "=" * 60)
print("  ANALYSIS COMPLETE — All reports saved to /reports folder")
print("=" * 60)
