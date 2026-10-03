"""Task 1 picture for Writing Test 3 (website writing test 13): the website's image was a copy of test 12's
olive-oil process, so this draws the chart its prompt describes (table + bar chart, commuters in a European city,
2005 vs 2020). usage: python3 seed/sources/web_tests/writing/draw_test13.py <out.jpg>"""
import sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

modes = ['Car', 'Bus', 'Train / metro', 'Bicycle']
share = {'2005': [52, 24, 16, 8], '2020': [38, 21, 27, 14]}
minutes = {'2005': [34, 41, 29, 22], '2020': [39, 44, 26, 21]}

fig = plt.figure(figsize=(10, 7.2), dpi=110)
fig.suptitle('Commuters in Lindenberg by transport mode, 2005 and 2020', fontsize=14, fontweight='bold')
ax = fig.add_axes([0.08, 0.40, 0.88, 0.48])
x = range(len(modes))
w = 0.38
b1 = ax.bar([i - w / 2 for i in x], share['2005'], w, label='2005', color='#3B5B92')
b2 = ax.bar([i + w / 2 for i in x], share['2020'], w, label='2020', color='#E3A23B')
for bars in (b1, b2):
    for b in bars:
        ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 0.8, f'{int(b.get_height())}%', ha='center', fontsize=10)
ax.set_xticks(list(x), modes, fontsize=11)
ax.set_ylabel('% of commuters', fontsize=11)
ax.set_ylim(0, 60)
ax.set_title('Proportion of commuters using each mode', fontsize=12)
ax.legend(frameon=False)
ax.spines[['top', 'right']].set_visible(False)

tax = fig.add_axes([0.12, 0.04, 0.78, 0.26])
tax.axis('off')
tax.set_title('Average one-way travel time (minutes)', fontsize=12)
rows = [[m, str(minutes['2005'][i]), str(minutes['2020'][i])] for i, m in enumerate(modes)]
tb = tax.table(cellText=rows, colLabels=['Transport mode', '2005', '2020'], loc='center', cellLoc='center')
tb.auto_set_font_size(False)
tb.set_fontsize(11)
tb.scale(1, 1.6)
for (r, c), cell in tb.get_celld().items():
    if r == 0:
        cell.set_facecolor('#DDE4F0')
        cell.set_text_props(fontweight='bold')
fig.savefig(sys.argv[1], format='jpg', pil_kwargs={'quality': 88})
print('wrote', sys.argv[1])
