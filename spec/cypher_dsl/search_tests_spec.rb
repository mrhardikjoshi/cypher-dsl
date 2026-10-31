# frozen_string_literal: true

# Translated from SearchTests.java.
#
# Adapted: the Java `Search#toString` (`Search{cypher=…}`) is `Search#cypher`; Java's
# NullPointerExceptions are ArgumentErrors.
module CypherDSL
  RSpec.describe 'SearchTests' do
    let(:movie) { Cypher.name(:movie) }
    let(:vector) { Cypher.vector([1, 2, 3]) }

    [
      [-> { Cypher.vector([1, 2, 3]) }, 'vector([1, 2, 3], 3, INTEGER NOT NULL)'],
      [-> { Cypher.literal_of([1, 2, 3]) }, '[1, 2, 3]'],
      [-> { Cypher.list_of(Cypher.literal_of(1), Cypher.literal_of(2), Cypher.literal_of(3)) }, '[1, 2, 3]'],
      [-> { Cypher.parameter(:snowWhiteEmbedding) }, '$snowWhiteEmbedding'],
      [-> { Cypher.name(:snowWhite).property(:embedding) }, 'snowWhite.embedding'],
      [-> { Cypher.node('Movie', Cypher.map_of('title', Cypher.literal_of('Snow White'))).named(:snowWhite).property(:embedding) }, 'snowWhite.embedding']
    ].each do |vector, vector_as_string|
      it "basic vector search clause (#{vector_as_string})" do
        top_k = 4
        search = Cypher.search(movie).in('moviePlots').for_vector(vector.call).limit(top_k).build
        expect(search.cypher).to eq("SEARCH movie IN (VECTOR INDEX moviePlots FOR #{vector_as_string} LIMIT 4)")
      end
    end

    it 'basic vector search clause with score' do
      top_k = 4
      search = Cypher.search(movie).in('moviePlots').for_vector(vector).limit(top_k).score(Cypher.name(:similarityScore)).build
      expect(search.cypher).to eq('SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) LIMIT 4) SCORE AS similarityScore')
    end

    it 'vector search with filters 1' do
      top_k = 4
      search = Cypher.search(movie)
                     .in('moviePlots')
                     .for_vector(vector)
                     .where(movie.property(:releaseDate).gt(Cypher.date('1990')))
                     .limit(top_k)
                     .score(Cypher.name(:similarityScore))
                     .build
      expect(search.cypher).to eq(
        "SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) WHERE movie.releaseDate > date('1990') LIMIT 4) SCORE AS similarityScore"
      )
    end

    it 'vector search with filters 2' do
      top_k = 4
      search = Cypher.search(movie)
                     .in('moviePlots')
                     .for_vector(vector)
                     .where(movie.property(:releaseDate).gt(Cypher.date('1990')), movie.property(:title).starts_with(Cypher.literal_of('A')))
                     .limit(top_k)
                     .score(Cypher.name(:similarityScore))
                     .build
      expect(search.cypher).to eq(
        "SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) WHERE (movie.releaseDate > date('1990') AND movie.title STARTS WITH 'A') LIMIT 4) SCORE AS similarityScore"
      )
    end

    describe 'ExceptionalStates' do
      it 'name is required' do
        expect { Cypher.search(nil) }.to raise_error(ArgumentError, 'Name is required')
      end

      it 'index name must not be null' do
        search = Cypher.search(Cypher.name(:movie))
        expect { search.in(nil) }.to raise_error(ArgumentError, 'The index name must not be null or empty')
      end

      it 'index name must not be empty' do
        search = Cypher.search(Cypher.name(:movie))
        expect { search.in('') }.to raise_error(ArgumentError, 'The index name must not be null or empty')
      end

      it 'index name must not be blank' do
        search = Cypher.search(Cypher.name(:movie))
        expect { search.in('   ') }.to raise_error(ArgumentError, 'The index name must not be null or empty')
      end

      it 'vector must not be null' do
        movie_plots = Cypher.search(Cypher.name(:movie)).in('moviePlots')
        expect { movie_plots.for_vector(nil) }.to raise_error(ArgumentError)
      end

      it 'vector expression must be supported' do
        movie_plots = Cypher.search(Cypher.name(:movie)).in('moviePlots')
        not_a_vector = Cypher.literal_of('not a vector')
        expect { movie_plots.for_vector(not_a_vector) }.to raise_error(ArgumentError, /\AUnsupported vector expression/)
      end

      it 'top k must not be negative' do
        movie_plots = Cypher.search(Cypher.name(:movie)).in('moviePlots').for_vector(Cypher.vector([1, 2, 3]))
        expect { movie_plots.limit(-1) }.to raise_error(ArgumentError, 'topK must be greater than or equal to 0')
      end

      it 'where only allows comparisons' do
        compound = movie.property(:releaseDate).gt(Cypher.date('1990')).and(movie.property(:title).starts_with(Cypher.literal_of('A')))
        movie_plots = Cypher.search(movie).in('moviePlots').for_vector(Cypher.vector([1, 2, 3]))
        expect { movie_plots.where(compound) }.to raise_error(ArgumentError, 'Only comparison conditions are supported')
      end

      it 'where does not allow null predicate' do
        movie_plots = Cypher.search(Cypher.name(:movie)).in('moviePlots').for_vector(Cypher.vector([1, 2, 3]))
        expect { movie_plots.where(nil) }.to raise_error(ArgumentError)
      end

      it 'where only allows comparisons in additional predicates' do
        valid = movie.property(:releaseDate).gt(Cypher.date('1990'))
        compound = movie.property(:rating).gt(Cypher.literal_of(7.5)).and(movie.property(:title).starts_with(Cypher.literal_of('A')))
        movie_plots = Cypher.search(movie).in('moviePlots').for_vector(Cypher.vector([1, 2, 3]))
        expect { movie_plots.where(valid, compound) }.to raise_error(ArgumentError, 'Only comparison conditions are supported')
      end
    end

    describe 'FullExamples' do
      let(:pretty) { Renderer.get_renderer(Renderer::Configuration.pretty_printing) }

      it 'find the most similar nodes with score' do
        similarity_score = Cypher.name(:similarityScore)

        search = Cypher.search(movie).in('moviePlots').for_vector(Cypher.vector([1, 2, 3])).limit(4).score(similarity_score).build

        stmt = Cypher.match(Cypher.node('Movie').named(movie))
                     .search(search)
                     .returning(movie.property(:title).as(:title), similarity_score)
                     .build

        expect(stmt.cypher).to eq(
          'MATCH (movie:`Movie`) SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) LIMIT 4) SCORE AS similarityScore RETURN movie.title AS title, similarityScore'
        )
        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          MATCH (movie:Movie)
            SEARCH movie IN (
              VECTOR INDEX moviePlots
              FOR vector([1, 2, 3], 3, INTEGER NOT NULL)
              LIMIT 4
            ) SCORE AS similarityScore
          RETURN movie.title AS title, similarityScore
        CYPHER
      end

      it 'vector search with filters' do
        search = Cypher.search(movie)
                       .in('moviePlots')
                       .for_vector(Cypher.vector([1, 2, 3]))
                       .where(movie.property(:releaseDate).gt(Cypher.date('1990')))
                       .limit(4)
                       .build

        stmt = Cypher.match(Cypher.node('Movie').named(movie))
                     .search(search)
                     .returning(movie.property(:title).as(:title), movie.property(:releaseDate).property(:year).as(:year))
                     .build

        expect(stmt.cypher).to eq(
          "MATCH (movie:`Movie`) SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) WHERE movie.releaseDate > date('1990') LIMIT 4) RETURN movie.title AS title, movie.releaseDate.year AS year"
        )
        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          MATCH (movie:Movie)
            SEARCH movie IN (
              VECTOR INDEX moviePlots
              FOR vector([1, 2, 3], 3, INTEGER NOT NULL)
              WHERE movie.releaseDate > date('1990')
              LIMIT 4
            )
          RETURN movie.title AS title, movie.releaseDate.year AS year
        CYPHER
      end

      it 'vector search with outer filters' do
        search = Cypher.search(movie).in('moviePlots').for_vector(Cypher.vector([1, 2, 3])).limit(4).build

        stmt = Cypher.match(Cypher.node('Movie').named(movie))
                     .search(search)
                     .where(movie.property(:releaseDate).gt(Cypher.date('1990')))
                     .returning(movie.property(:title).as(:title), movie.property(:releaseDate).property(:year).as(:year))
                     .build

        expect(stmt.cypher).to eq(
          "MATCH (movie:`Movie`) SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) LIMIT 4) WHERE movie.releaseDate > date('1990') RETURN movie.title AS title, movie.releaseDate.year AS year"
        )
        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          MATCH (movie:Movie)
            SEARCH movie IN (
              VECTOR INDEX moviePlots
              FOR vector([1, 2, 3], 3, INTEGER NOT NULL)
              LIMIT 4
            )
          WHERE movie.releaseDate > date('1990')
          RETURN movie.title AS title, movie.releaseDate.year AS year
        CYPHER
      end

      it 'vector search with filters and where clause' do
        search = Cypher.search(movie)
                       .in('moviePlots')
                       .for_vector(Cypher.vector([1, 2, 3]))
                       .where(movie.property(:releaseDate).gt(Cypher.date('1990')))
                       .limit(4)
                       .build

        stmt = Cypher.match(Cypher.node('Movie').named(movie))
                     .search(search)
                     .where(movie.property(:rating).gt(Cypher.literal_of(7.5)))
                     .returning(movie.property(:title).as(:title), movie.property(:releaseDate).property(:year).as(:year))
                     .build

        expect(stmt.cypher).to eq(
          "MATCH (movie:`Movie`) SEARCH movie IN (VECTOR INDEX moviePlots FOR vector([1, 2, 3], 3, INTEGER NOT NULL) WHERE movie.releaseDate > date('1990') LIMIT 4) WHERE movie.rating > 7.5 RETURN movie.title AS title, movie.releaseDate.year AS year"
        )
        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          MATCH (movie:Movie)
            SEARCH movie IN (
              VECTOR INDEX moviePlots
              FOR vector([1, 2, 3], 3, INTEGER NOT NULL)
              WHERE movie.releaseDate > date('1990')
              LIMIT 4
            )
          WHERE movie.rating > 7.5
          RETURN movie.title AS title, movie.releaseDate.year AS year
        CYPHER
      end

      it 'vector search with filter with an and predicate on separate properties' do
        snow_white = Cypher.node('Movie', Cypher.map_of('title', Cypher.literal_of('Snow White'))).named(:snowWhite)

        search = Cypher.search(movie)
                       .in('moviePlots')
                       .for_vector(snow_white.property(:embedding))
                       .where(movie.property(:releaseDate).lt(Cypher.date('2000')), movie.property(:rating).gte(snow_white.property(:rating)))
                       .limit(4)
                       .build

        stmt = Cypher.match(snow_white)
                     .match(Cypher.node('Movie').named(movie))
                     .search(search)
                     .returning(movie.property(:title).as(:title), movie.property(:releaseDate).property(:year).as(:year))
                     .build

        expect(stmt.cypher).to eq(
          "MATCH (snowWhite:`Movie` {title: 'Snow White'}) MATCH (movie:`Movie`) SEARCH movie IN (VECTOR INDEX moviePlots FOR snowWhite.embedding WHERE (movie.releaseDate < date('2000') AND movie.rating >= snowWhite.rating) LIMIT 4) RETURN movie.title AS title, movie.releaseDate.year AS year"
        )
        expect(pretty.render(stmt)).to eq(<<~CYPHER.chomp)
          MATCH (snowWhite:Movie {
            title: 'Snow White'
          })
          MATCH (movie:Movie)
            SEARCH movie IN (
              VECTOR INDEX moviePlots
              FOR snowWhite.embedding
              WHERE (movie.releaseDate < date('2000')
                AND movie.rating >= snowWhite.rating)
              LIMIT 4
            )
          RETURN movie.title AS title, movie.releaseDate.year AS year
        CYPHER
      end
    end
  end
end
