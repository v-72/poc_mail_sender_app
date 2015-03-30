#!/usr/local/bin


###############################Mass Mail Sender v: 1.0###########################################
#                                                                                               #
# Author : vihegde@akamai.com                                                                   #
#                                                                                               #
# Purpose : Send mass email notifications                                                       #
#                                                                                               #
#################################################################################################
import sys
import csv
from smtplib import SMTP
from email.mime.image import MIMEImage
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

emails_sent = 0
total_errors = 0

def help():

    print(""" Mass Mail Sender v: 1.0\n
            Input required required:\n
                Input CSV File(should contain to,cc,host and optional other fields)\n
                Input Template File(bind fields between %% with separating comma in case of multiple fields[ex: %host,window%])\n
                Groupping will be done based on To and CC combination\n\n
                """
                )
    main()


def main():

    try:
        server_data = []
        csv_header = 0
        input_prompt = """Enter CSV File Name:\n"""
        f = open("Success","w")
        f.write("***************************************Success Log*****************************************")
        f.close()
        fp = open("Error","w")
        fp.write("***************************************Error Log*****************************************")
        fp.close()

        input_filename = raw_input(input_prompt)
        try:
            with open(input_filename,'r') as f:
                csv_handler = csv.reader(f)
                csv_header = next(csv_handler)
                for row in csv_handler:
                    server_data.append(row)

        except:
            print "Invalid CSV Name"

    except:
        print "Error Occured"
    try:
        validator(csv_header,server_data)
    except:
        print "Error Occurred while calling validator function"

    print "\n\nTotal emails sent: "+str(emails_sent)+"\nErrors: "+str(total_errors)
    print("\nCheck Success and Error Log for more information")




#validate input data
def validator(csv_header,server_data):
    no_of_columns = len(csv_header)
    no_of_rows = len(server_data)
    server_map = {}
    lower_header = []
    try:
        for i in csv_header:
            lower_header.append(i.lower())

    except:
        print "CSV File Wrong Format"
    keys_prompt = """Groupping will be done using To and CC Field\Enter template file name:"""

    template = raw_input(keys_prompt)
    from_address = raw_input("Enter from address:\n")
    additional_cc = raw_input("Enter additional cc address:\n")
    subject =raw_input("Enter Subject Line:\n")
    try:
        template_file_pointer = open(template,'r')
        template_content = template_file_pointer.read()
        print template_content
        groupping_help_array = ((template_content.split('%'))[1]).split(',')
        print groupping_help_array
        place_holder = (template_content.split('%'))[1]
        groupping_index = [lower_header.index('to'),lower_header.index('cc')]
        for i in groupping_help_array:
            i = i.lower()
            groupping_index.append(lower_header.index(i))

        for i in server_data:
            if i[groupping_index[0]] in server_map:
                if i[groupping_index[1]] in server_map[i[groupping_index[0]]]:
                    temp_server_data = {}
                    for index_count in range(2,len(groupping_index)):
                        temp_server_data[lower_header[groupping_index[index_count]]] = i[groupping_index[index_count]]
                    server_map[i[groupping_index[0]]][i[groupping_index[1]]].append(temp_server_data)

                else:
                    temp_server_data = {}
                    for index_count in range(2,len(groupping_index)):
                        temp_server_data[lower_header[groupping_index[index_count]]] = i[groupping_index[index_count]]
                    server_map[i[groupping_index[0]]][i[groupping_index[1]]] = [temp_server_data]

            else:
                temp_server_data = {}
                for index_count in range(2,len(groupping_index)):
                    temp_server_data[lower_header[groupping_index[index_count]]] = i[groupping_index[index_count]]
                #print temp_server_data
                cc_data = {}
                cc_data[i[groupping_index[1]]] = [temp_server_data]
                server_map[i[groupping_index[0]]] = cc_data

        def mail_send_helper():
            try:
                for k,v in server_map.items():
                    to = k
                    for kk,vv in v.items():
                        cc = kk
                        host_details = ''
                        for i in vv:
                            host__ = ''
                            for j in groupping_help_array:
                                host__ = host__+i[j]+'  '
                            host_details = host_details+host__+'<br>'

                            place_holder_ = '%'+place_holder+'%'
                            text = template_content.replace(place_holder_,host_details)

                        #print text
                        sender(to,cc,text,subject,from_address,additional_cc)

            except:
                print "Error in template rendering"
        no_of_unique_owners = len(server_map.keys())
        no_of_to_cc_combinations = 0
        for k,v in server_map.items():
            for kk in v.keys():
                no_of_to_cc_combinations += 1
        print(server_map)
        print "\n\n****************************Pre mail Send Report*********************************"
        print "Number of columns in csv: "+str(no_of_columns)+"\nColumn headers: "+str(lower_header)+"\nNumber of rows: "+str(no_of_rows)+"\nNumber of Unique Owners: "+str(no_of_unique_owners)+"\nNumber of unique to,cc combinations: "+str(no_of_to_cc_combinations)+"\nNumber mails will be sent: "+str(no_of_to_cc_combinations)+"\nColumns used in email body: "+str(place_holder)

        answer = raw_input("************************************************************\n\nCan I send mail Now ?(yes/no):")
        if answer == 'yes':
            mail_send_helper()
        else:
            exit

    except:
        print "Error In Reading template"




#------ Send Email ------
def sender(to,cc,text,subject,from_address,additional_cc):
    if cc == '':
        CC = additional_cc

    else:
        CC = cc+';'+additional_cc
    def func_success():
        global emails_sent
        emails_sent += 1
        f = open("Success","a")
        f.write('\n---------------------------------------------------------\n')
        f.write('From:'+from_address+'\n')
        f.write('To: '+to+'\n')
        f.write('CC: '+CC+'\n')
        f.write('Subject: '+subject+'\n')
        f.write('Email Body: \n'+text)
        f.write('\n---------------------------------------------------------\n')
        f.close()



    def func_failure():
        global total_errors
        total_errors += 1
        f = open("Error","a"+'\n')
        f.write('\n---------------------------------------------------------\n')
        f.write('From:'+from_address+'\n')
        f.write('To: '+to+'\n')
        f.write('CC: '+CC+'\n')
        f.write('Subject: '+subject+'\n')
        f.write('Email Body: \n'+text)
        f.write('\n---------------------------------------------------------\n')
        f.close()

    #Handeling message header
    msg = MIMEMultipart()
    msg['TO'] = to
    msg['CC'] = CC
    msg['From'] = from_address
    msg['Subject'] = subject
    text_mail = MIMEText(text, 'html')
    text_mail.add_header("Content-Disposition", "inline")
    msg.attach(text_mail)
    #Send Email
    try:
        s = SMTP('smtp.akamai.com')
        sending_address = to+';'+additional_cc
        print sending_address
        s.sendmail(msg['From'],to, msg.as_string())
        s.sendmail(msg['From'],CC, msg.as_string())
        func_success()

    except:
        func_failure()
        pass




def logger():
    pass



help()





