import numpy as np
import pandas as pd
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import LogisticRegression
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from sklearn.model_selection import train_test_split
from sklearn import metrics
import string
import spacy
np.random.seed(42)
from tqdm.notebook import tqdm
import dateparser
import matplotlib.pyplot as plt
import seaborn as sns
plt.style.use('ggplot')
import nltk


nlp = spacy.load("en_core_web_sm")
stop_words = nlp.Defaults.stop_words
punctuations = string.punctuation
to_remove = ['urllink', 'jpg', 'nbsp', 'http', 'www']



def clean_and_transform(data):
    # remove rows without topic and date and reset index
    data = data.loc[data['topic']!='indUnk',:]
    data = data.dropna()
    data = data.reset_index(drop = True)

    # create column for word count
    data.loc[:,'word_count'] = data.loc[:,'text'].apply(lambda x: len(x.split()))

    # create unique id for each blog
    data.loc[:, 'blog_id'] = data.index.astype(str)
    data.loc[:, 'blog_id'] = data.blog_id.apply(lambda x : '1'+x.zfill(6))

    # clean up the date in multiple language
    for ind, row in data.iterrows():
        try:
            date_raw = row['date']
            clean_date = dateparser.parse(date_raw)
            data.loc[ind,'date_clean'] = clean_date
        except Exception as e:
            print(ind, e)

    # after cleaning there're extra rows for data after 2004, remove those
    data = data.loc[data['date_clean']<'2005-01-01',:]

    # rename and arrange the columns
    data_clean = data.rename(columns = {'id':'author_id', 'date':'date_raw', 'date_clean': 'date','topic':'occupation'})
    data_clean = data_clean.loc[:,['author_id', 'gender', 'age','occupation', 'sign', 'blog_id','date','text', 'word_count']]

    return data_clean



def clean_text(sentence):
    import re
    # create token object
    doc = nlp(sentence)

    mytokens = [word.lemma_.lower().strip() for word in doc] # lemmatize token and convert into lower case
    mytokens = [re.sub(r'\W+',' ',token) for token in mytokens] # replace everything non-alpahnumeric by ' '
    mytokens = [re.sub(r'\s+',' ',token) for token in mytokens] # replace one or more whitespaces by  ' '
    mytokens = [re.sub(r'\d+',' ',token) for token in mytokens] # replace one or more digits by ' '
    
    # remove stopwords, punctuation and empty string
    mytokens = [word.strip() for word in mytokens if word not in stop_words and word not in punctuations and word not in to_remove and len(word) > 1]
    mytokens = [word for word in mytokens if word]
    clean_text = " ".join(mytokens)
    return clean_text


def clean_and_export(data):
    data = clean_and_transform(data_raw)
    data.to_csv('blog_author_clean.csv', index = False) # export cleaned data as csv (text not cleaned yet)
    data.loc[:,'clean_text'] = data['text'].apply(clean_text)
    data.to_csv('cleaned_text_dump.csv', index=False)


data_raw = pd.read_csv('blogtext.csv')
clean_and_export(data_raw)