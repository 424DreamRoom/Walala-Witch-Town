from pathlib import Path
p=Path(__file__).with_name('core_residents_build.py')
s=p.read_text(encoding='utf-8-sig')
s=s.replace('\nflush()\n','\n')
s+='''\n# Cross-character events depend on the facts they mention.\ncross_requires={\n 'core_mori_04':['core_reed_03'],\n 'core_reed_04':['core_mori_04'],\n 'core_bei_04':['core_mori_04'],\n 'core_nagi_04':['core_toma_04'],\n 'core_dou_04':['core_toma_04'],\n 'core_xing_04':['core_toma_04'],\n}\nfor scene in scenes:\n for req in cross_requires.get(scene['id'],[]):\n  if req not in scene['requires']:scene['requires'].append(req)\n if scene['id']=='core_sui_03':\n  for line in scene['lines']:\n   line['text']=line['text'].replace('我早餐摊也一样','我早上试卖的那几碗也一样').replace('早餐摊的上月尾款','食堂的上月尾款')\n if scene['id']=='core_bai_03':scene['location']='食堂试卖早餐处'\nflush()\n'''
p.write_text(s,encoding='utf-8')
