#counts how many words are in the main page of the course website
#libraries to connect and read webpage
import requests
from string import punctuation
from collections import Counter
from bs4  import BeautifulSoup

# get the url of webpage
r = requests.get("https://cs.memphis.edu/~vrus/teaching/ir-websearch/")
text = BeautifulSoup(r.content)

# collect the words from all paragrphs
text_paragraph = (''.join(s.findAll(text=True))for s in text.findAll('p'))
c_p = Counter((i.strip().strip(punctuation).lower() for j in text_paragraph for i in j.split()))

# get the words within divs ; div is used as a container to represent an area on the screen
text_div = (''.join(s.findAll(text=True))for s in text.findAll('div'))
c_div = Counter((i.strip().strip(punctuation).lower() for j in text_div for i in j.split()))

#  count the sums of words of paragraphs and divs and get a list with the words count 
sumofwords = c_div + c_p
list_the_words = sumofwords.most_common()
#print the words in alphabetical order
sorted(total.most_common())