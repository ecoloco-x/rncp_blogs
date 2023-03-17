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
from transformers import AutoTokenizer
from transformers import AutoModelForSequenceClassification
from scipy.special import softmax
import torch
from nltk.sentiment.vader import SentimentIntensityAnalyzer
import time

data_raw = pd.read_csv("C:/Users/ykxio/Desktop/Ironhack/ykhack/project/cleaned_text_dump.csv")
data_raw = data_raw[(data_raw['word_count']>5) & (data_raw['word_count']<200)]
data_raw = data_raw.dropna()
data_raw.loc[:,'gender'] = [1 if x =='female' else 0 for x in data_raw['gender']]
data_raw.loc[:,'age_coded'] = np.where(data_raw['age']<20,0,
                                 np.where(data_raw['age']<30,1,
                                 np.where(data_raw['age']<40,2,3)))
data_raw.reset_index(drop = True, inplace=True)

sia = SentimentIntensityAnalyzer()

data = data_raw[:20000]
print('imported')


MODEL = "cardiffnlp/twitter-roberta-base-sentiment"
tokenizer = AutoTokenizer.from_pretrained(MODEL)
print('tokenizer finished')
model = AutoModelForSequenceClassification.from_pretrained(MODEL)

def roberta_polarity(text):
    encoded_text = tokenizer(text, return_tensors='pt')
    output = model(**encoded_text)
    score = output[0][0].detach().numpy()
    score = softmax(score)
    score_dict = {
        'roberta_neg': score[0],
        'roberta_neu':score[1],
        'reberta_pos':score[2]
    }
    return score_dict

start = time.time()
res = {}
for i, row in data.iterrows():
    try:            
        text = row['text']
        id = row['blog_id'] 
        vader_score =sia.polarity_scores(text)
        vader_score_rename = {}
        for key, value in vader_score.items():
            vader_score_rename[f'vader_{key}'] = value
        roberta_score = roberta_polarity(text)
        both = {**vader_score_rename, **roberta_score}
        res[id] = both
    except Exception as e:
        print(f'broke for {id} {e}')
    if i % 500 == 0:
        print(f"{i} rows processed out of {len(data)}")

end = time.time()
print(end - start)


result_both = pd.DataFrame(res).T
result_both = result_both.reset_index().rename(columns = {'index':'blog_id'})
result_both = result_both.merge(data, how='left')

result_both.to_csv("C:/Users/ykxio/Desktop/Ironhack/ykhack/project/sentiment.csv", index= False)
print('finished')