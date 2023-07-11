import boto3
import os
import datetime
import calendar

def get_month_start_end_dates():
    today = datetime.date.today()
    start_date = today.replace(day=1)
    end_date = today.replace(day=calendar.monthrange(today.year, today.month)[1])
    return start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')

def lambda_handler(event, context):
    # Variablize the account ID
    account_id = os.environ['ACCOUNT_ID']

    # Fetch the SNS topic ARN from the Parameter Store
    ssm_client = boto3.client('ssm')
    response = ssm_client.get_parameter(Name='sns_topic_billing')
    sns_topic_arn = response['Parameter']['Value']

    # Create a Cost Explorer client
    client = boto3.client('ce')

    # Set the current date as the start date for the cost forecast
    current_date = datetime.datetime.now().strftime('%Y-%m-%d')

    # Get the start and end dates for the current month
    start_date, end_date = get_month_start_end_dates()

    # Get the start and end dates for the previous month
    previous_month = datetime.datetime.now().replace(day=1) - datetime.timedelta(days=1)
    previous_start_date = previous_month.replace(day=1).strftime('%Y-%m-%d')
    previous_end_date = previous_month.strftime('%Y-%m-%d')

    # Set the parameters for the API request to retrieve MTD balance
    mtd_balance_response = client.get_cost_and_usage(
        TimePeriod={
            'Start': start_date,
            'End': end_date
        },
        Filter={
            'Dimensions': {
                'Key': 'LINKED_ACCOUNT',
                'Values': [
                    account_id,    # key is AWS account number
                ]
            },
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost']
    )
    mtd_balance = float(mtd_balance_response['ResultsByTime'][0]['Total']['UnblendedCost']['Amount'])

    # Set the parameters for the API request to retrieve current month's total forecast
    forecast_response = client.get_cost_forecast(
        TimePeriod={
            'Start': current_date,
            'End': end_date
        },
        Filter={
            'Dimensions': {
                'Key': 'LINKED_ACCOUNT',
                'Values': [
                    account_id,    # key is AWS account number
                ]
            },
        },
        Metric='UNBLENDED_COST',
        Granularity='MONTHLY'
    )
    forecast = float(forecast_response['Total']['Amount'])

    # Set the parameters for the API request to retrieve prior month's data
    prior_month_response = client.get_cost_and_usage(
        TimePeriod={
            'Start': previous_start_date,
            'End': previous_end_date
        },
        Filter={
            'Dimensions': {
                'Key': 'LINKED_ACCOUNT',
                'Values': [
                    account_id,    # key is AWS account number
                ]
            },
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost']
    )
    prior_month_data = prior_month_response['ResultsByTime']

    # Generate the email content with the retrieved data and trend values
    email_subject = f'Billing Report for Account:{account_id}'
    email_body = f"MTD Balance: {mtd_balance:.2f}\n"

    # Add current month's period
    email_body += f"Current Month's period: {start_date} to {current_date}\n"
    email_body += f"Current Month's Forecast: {forecast:.2f}\n\n"

    # Add prior month's data
    email_body += "Prior Month's Data:\n"
    for data in prior_month_data:
        start = data['TimePeriod']['Start']
        end = data['TimePeriod']['End']
        cost = float(data['Total']['UnblendedCost']['Amount'])
        email_body += f"Prior Month's bill: {cost:.2f}\n"
        email_body += f"Prior Month's period: {start} to {end}\n\n"

    # Send the email using Amazon SNS
    sns_client = boto3.client('sns')

    response = sns_client.publish(
        TopicArn=sns_topic_arn,
        Message=email_body,
        Subject=email_subject
    )
